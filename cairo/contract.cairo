// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.4.0 (token/erc20/presets/ERC20.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from introspection.ERC165.library import ERC165
from token.ERC20.library import ERC20
from token.ERC721.IERC721 import IERC721
from utils.constants.library import (
    IERC20_ID,
    IERC20Metadata_ID,
    IERC721_RECEIVER_ID,
    L1_CONTRACT_ADDRESS,
)
from core.NFT.library import NFT, nft_listings, nft_key_contract_address
from core.DAO.library import (
    DAO,
    nft_appraisal_period,
    nft_appraisal_fee,
    nft_l1_extra_lockup_period,
)
from core.FIN.library import FIN, user_fees, manager_of
from starkware.cairo.common.bool import TRUE
from starkware.starknet.common.syscalls import get_caller_address, deploy, get_contract_address
from starkware.starknet.common.messages import send_message_to_l1
from starkware.cairo.common.math import assert_lt, assert_le, assert_not_zero

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    name: felt,
    symbol: felt,
    decimals: felt,
    initial_supply: Uint256,
    recipient: felt,
    nft_appraisal_period: felt,
    nft_l1_extra_lockup_period: felt,
    nft_appraisal_fee: felt,
    class_hash: felt,
) {
    ERC165.register_interface(IERC20_ID);
    ERC165.register_interface(IERC20Metadata_ID);
    ERC165.register_interface(IERC721_RECEIVER_ID);
    ERC20.initializer(name, symbol, decimals);
    ERC20._mint(recipient, initial_supply);
    DAO.initializer(nft_appraisal_period, nft_l1_extra_lockup_period, nft_appraisal_fee);
    let (owner_contract_address) = get_contract_address();
    let (contract_address) = deploy(
        class_hash,
        0,
        constructor_calldata_size=1,
        constructor_calldata=cast(new (owner_contract_address,), felt*),
        deploy_from_zero=FALSE,
    );
    nft_key_contract_address.write(contract_address);
    return ();
}

//
// Getters
//

@view
func supportsInterface{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    interfaceId: felt
) -> (success: felt) {
    return ERC165.supports_interface(interfaceId);
}

@view
func name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (name: felt) {
    return ERC20.name();
}

@view
func symbol{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (symbol: felt) {
    return ERC20.symbol();
}

@view
func totalSupply{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    totalSupply: Uint256
) {
    let (totalSupply: Uint256) = ERC20.total_supply();
    return (totalSupply=totalSupply);
}

@view
func decimals{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    decimals: felt
) {
    return ERC20.decimals();
}

@view
func balanceOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(account: felt) -> (
    balance: Uint256
) {
    return ERC20.balance_of(account);
}

@view
func allowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, spender: felt
) -> (remaining: Uint256) {
    return ERC20.allowance(owner, spender);
}

//
// Externals
//

@external
func onERC721Received{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    TRUE, from_: felt, tokenId: Uint256, data_len: felt, data: felt*
) -> (selector: felt) {
    let (caller) = get_caller_address();
    let is_approved = FIN.is_approved_or_owner(caller, from_);
    assert_not_zero(is_approved * caller);
    let (nft_appraisal_fee_) = nft_appraisal_fee.read();
    let (available_fees) = user_fees.read(from_);
    assert_le(nft_appraisal_fee_, available_fees);
    user_fees.write(from_, available_fees - nft_appraisal_fee_);
    let (nft_appraisal_period_) = nft_appraisal_period.read();
    return NFT.onReceivedFromL2(caller, from_, tokenId, data_len, data, nft_appraisal_period_);
}

@external
func appraise_nft{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    collection_address: felt,
    from_: felt,
    token_id: Uint256,
    appraisal_value: Uint256,
    power_token_amount: Uint256,
) -> (success: felt) {
    let (nft_) = nft_listings.read(collection_address, token_id);
    return FIN.appraise_nft(
        from_,
        collection_address,
        token_id,
        nft_.appraisal_post_expiry_date,
        appraisal_value,
        power_token_amount,
    );
}

@external
func verify_median_appraisal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    index_of_median: felt,
    collection_address: felt,
    token_id: Uint256,
    nft_member_appraisals_len: felt,
    nft_member_appraisals: felt*,
) -> (success: felt) {
    let (nft_) = nft_listings.read(collection_address, token_id);
    return FIN.verify_median_appraisal(
        index_of_median,
        collection_address,
        token_id,
        nft_member_appraisals_len,
        nft_member_appraisals,
        nft_.appraisal_post_expiry_date,
        nft_.fundraising_post_expiry_date,
    );
}

@external
func transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient: felt, amount: Uint256
) -> (success: felt) {
    return ERC20.transfer(recipient, amount);
}

@external
func transferFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender: felt, recipient: felt, amount: Uint256
) -> (success: felt) {
    return ERC20.transfer_from(sender, recipient, amount);
}

@external
func approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, amount: Uint256
) -> (success: felt) {
    return ERC20.approve(spender, amount);
}

@external
func increaseAllowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, added_value: Uint256
) -> (success: felt) {
    return ERC20.increase_allowance(spender, added_value);
}

@external
func decreaseAllowance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, subtracted_value: Uint256
) -> (success: felt) {
    return ERC20.decrease_allowance(spender, subtracted_value);
}

@l1_handler
func onERC721ReceivedFromL1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    from_address: felt,
    collection_address: felt,
    from_: felt,
    token_id_low_bits: felt,
    token_id_high_bits: felt,
    appraisal_fee: felt,
    nft_debt_period: felt,
    nft_post_expiry: felt,
) {
    assert L1_CONTRACT_ADDRESS = from_address;

    let (nft_appraisal_period_) = nft_appraisal_period.read();

    let (nft_appraisal_fee_) = nft_appraisal_fee.read();

    let (nft_l1_extra_lockup_period_) = nft_l1_extra_lockup_period.read();

    NFT.onReceivedFromL1(
        collection_address,
        from_,
        Uint256(token_id_low_bits, token_id_high_bits),
        nft_appraisal_period_,
        nft_l1_extra_lockup_period_,
        appraisal_fee,
        nft_appraisal_fee_,
        nft_debt_period,
        nft_post_expiry,
    );

    return ();
}

@l1_handler
func transferFeesL2{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    from_address: felt, from_: felt, fee_amount: felt
) {
    assert L1_CONTRACT_ADDRESS = from_address;
    return FIN.transferFeesL2(from_, fee_amount);
}

@external
func transferFeesL1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    from_: felt, amount: felt
) -> (success: felt) {
    let (caller) = get_caller_address();
    let is_approved = FIN.is_approved_or_owner(caller, from_);
    assert_not_zero(is_approved);
    return FIN.transferFeesL1(from_, amount);
}

@external
func approveFeeManager{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    manager: felt
) -> (success: felt) {
    let (from_) = get_caller_address();
    manager_of.write(from_, manager);
    return (success=TRUE);
}
