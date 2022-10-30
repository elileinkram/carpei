// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.4.0 (token/erc20/presets/ERC20.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from introspection.erc165.library import ERC165
from tokens.erc20.library import ERC20
from tokens.erc721.IERC721 import IERC721
from utils.constants.library import IERC721_RECEIVER_ID, IERC20_ID, IERC20Metadata_ID
from core.gallery.library import NFT, nft_listings
from core.council.library import DAO, nft_fundraising_period, nft_appraisal_period
from core.bank.library import TOKEN
from starkware.cairo.common.bool import TRUE

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    name: felt,
    symbol: felt,
    decimals: felt,
    initial_supply: Uint256,
    recipient: felt,
    nft_fundraising_period: felt,
    nft_appraisal_period: felt,
) {
    ERC165.register_interface(IERC20_ID);
    ERC165.register_interface(IERC20Metadata_ID);
    ERC165.register_interface(IERC721_RECEIVER_ID);
    ERC20.initializer(name, symbol, decimals);
    ERC20._mint(recipient, initial_supply);
    DAO.initializer(nft_fundraising_period, nft_appraisal_period);
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
    let (nft_appraisal_period_) = nft_appraisal_period.read();
    let (nft_fundraising_period_) = nft_fundraising_period.read();
    return NFT.onReceived(
        from_, tokenId, data_len, data, nft_appraisal_period_, nft_fundraising_period_
    );
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
    return TOKEN.appraise_nft(
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
    return TOKEN.verify_median_appraisal(
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
