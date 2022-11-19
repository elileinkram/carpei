// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.4.0 (token/erc20/presets/ERC20.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_check,
    uint256_lt,
    assert_uint256_le,
    assert_uint256_lt,
)
from introspection.ERC165.library import ERC165
from token.ERC20.library import ERC20
from token.ERC721.IERC721 import IERC721
from starkware.cairo.common.alloc import alloc
from utils.constants.library import (
    IERC20_ID,
    IERC20Metadata_ID,
    IERC721_RECEIVER_ID,
    L1_NFT_CONTRACT_ADDRESS,
    L1_TOKEN_CONTRACT_ADDRESS,
    DEPOSIT_TOKEN_L1_CODE,
)
from core.NFT.library import NFT, nft_listings, nft_key_contract_address, nft_nonce
from core.DAO.library import (
    DAO,
    nft_appraisal_period,
    nft_appraisal_fee,
    nft_l1_extra_lockup_period,
)
from core.FIN.library import (
    FIN,
    user_fees,
    user_fee_delegate,
    appraisal_token_allowances,
    power_token_balances,
    nft_appraisals,
    Appraisal,
)
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.starknet.common.syscalls import (
    get_caller_address,
    deploy,
    get_contract_address,
    get_block_timestamp,
)
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
    alloc_locals;
    let (caller) = get_caller_address();
    let is_approved = FIN.is_approved_or_owner_of_fees(caller, from_);
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
    token_id: Uint256,
    l1_native: felt,
    account: felt,
    delegate: felt,
    appraisal_value: Uint256,
    power_token_amount: Uint256,
) -> (success: felt) {
    alloc_locals;
    uint256_check(appraisal_value);
    uint256_check(power_token_amount);
    let (user_balance) = ERC20.balance_of(account);
    assert_uint256_le(power_token_amount, user_balance);
    let (power_balance) = power_token_balances.read(account);
    let (increase_power_balance) = uint256_lt(power_balance, power_token_amount);
    if (increase_power_balance == TRUE) {
        power_token_balances.write(account, power_token_amount);
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    } else {
        tempvar syscall_ptr = syscall_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar range_check_ptr = range_check_ptr;
    }
    let (nft_) = nft_listings.read(collection_address, token_id, l1_native);
    let res = nft_.key.low * nft_.key.high;
    assert_not_zero(res);
    let appraisal_post_expiry = nft_.appraisal_post_expiry_date;
    let (block_timestamp) = get_block_timestamp();
    assert_lt(block_timestamp, appraisal_post_expiry);
    let (appraisal: Appraisal) = nft_appraisals.read(
        collection_address, token_id, account, delegate, appraisal_post_expiry
    );
    return FIN.appraise_nft(
        collection_address,
        token_id,
        account,
        delegate,
        appraisal_post_expiry,
        appraisal_value,
        appraisal.power_token_amount,
        power_token_amount,
    );
}

// @external
// func verify_median_appraisal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
//     index_of_median: felt,
//     collection_address: felt,
//     token_id: Uint256,
//     nft_member_appraisals_len: felt,
//     nft_member_appraisals: felt*,
// ) -> (success: felt) {
//     let (nft_) = nft_listings.read(collection_address, token_id);
//     return FIN.verify_median_appraisal(
//         index_of_median,
//         collection_address,
//         token_id,
//         nft_member_appraisals_len,
//         nft_member_appraisals,
//         nft_.appraisal_post_expiry_date,
//         nft_.fundraising_post_expiry_date,
//     );
// }

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
    assert L1_NFT_CONTRACT_ADDRESS = from_address;

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
func receive_fees_from_l1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    from_address: felt, from_: felt, fee_amount: felt
) {
    assert L1_NFT_CONTRACT_ADDRESS = from_address;
    return FIN.receive_fees_from_l1(from_, fee_amount);
}

@l1_handler
func receive_tokens_from_l1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    from_address: felt, from_: felt, token_amount_low_bits: felt, token_amount_high_bits: felt
) {
    assert L1_TOKEN_CONTRACT_ADDRESS = from_address;
    ERC20._mint(from_, Uint256(token_amount_low_bits, token_amount_high_bits));
    return ();
}

@external
func transfer_tokens_to_l1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: Uint256
) -> (success: felt) {
    let (caller) = get_caller_address();
    ERC20._burn(caller, amount);
    let (payload: felt*) = alloc();
    assert payload[0] = caller;
    assert payload[1] = amount.low;
    assert payload[2] = amount.high;
    assert payload[3] = DEPOSIT_TOKEN_L1_CODE;
    send_message_to_l1(L1_TOKEN_CONTRACT_ADDRESS, 4, payload);
    return (success=TRUE);
}

@external
func transfer_fees_to_l1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt
) -> (success: felt) {
    return FIN.transfer_fees_to_l1(amount);
}

@external
func approveFeeManager{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    delegate: felt
) -> (success: felt) {
    let (from_) = get_caller_address();
    user_fee_delegate.write(from_, delegate);
    return (success=TRUE);
}
