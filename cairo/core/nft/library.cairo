// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.4.0 (introspection/erc165/library.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from utils.constants.library import IERC721_RECEIVER_ID
from starkware.starknet.common.syscalls import (
    get_contract_address,
    get_block_timestamp,
    get_caller_address,
)
from token.ERC721.IERC721 import IERC721
from token.ERC721.IERC721MintableBurnable import IERC721MintableBurnable

from starkware.cairo.common.uint256 import Uint256, uint256_check, assert_uint256_eq
from starkware.cairo.common.math import assert_not_zero, assert_le, split_felt, assert_lt
from starkware.cairo.common.bool import TRUE, FALSE
from security.safemath.library import SafeUint256
from starkware.cairo.common.alloc import alloc

struct NFT_ {
    from_: felt,
    appraisal_post_expiry_date: felt,
    debt_post_expiry_date: felt,
    key: Uint256,
}

@storage_var
func nft_listings(collection_address: felt, token_id: Uint256, l1_native: felt) -> (nft: NFT_) {
}

@storage_var
func nft_key_contract_address() -> (contract_address: felt) {
}

@storage_var
func nft_nonce() -> (nonce: Uint256) {
}

@event
func nft_registered(collection_address: felt, token_id: Uint256, l1_native: felt) {
}

namespace NFT {
    func onReceivedFromL2{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        collection_address: felt,
        from_: felt,
        tokenId: Uint256,
        data_len: felt,
        data: felt*,
        nft_appraisal_period: felt,
    ) -> (selector: felt) {
        assert TRUE = data_len;
        let nft_debt_period = data[0];
        assert_lt(nft_appraisal_period, nft_debt_period);
        let (block_timestamp) = get_block_timestamp();
        let appraisal_post_expiry_date: felt = block_timestamp + nft_appraisal_period + 1;
        let (nft_key_contract_address_) = nft_key_contract_address.read();
        let (nonce: Uint256) = nft_nonce.read();
        let (key: Uint256) = SafeUint256.add(nonce, Uint256(1, 0));
        nft_nonce.write(key);
        IERC721MintableBurnable.safeMint(nft_key_contract_address_, from_, key);
        return _onReceived(
            collection_address,
            from_,
            tokenId,
            FALSE,
            appraisal_post_expiry_date,
            nft_debt_period,
            key,
        );
    }

    func onReceivedFromL1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        collection_address: felt,
        from_: felt,
        token_id: Uint256,
        nft_appraisal_period: felt,
        nft_l1_extra_lockup_period: felt,
        appraisal_fee: felt,
        nft_appraisal_fee: felt,
        nft_debt_period: felt,
        nft_post_expiry: felt,
    ) {
        assert_lt(nft_appraisal_period, nft_debt_period);
        assert_le(nft_appraisal_fee, appraisal_fee);
        let (block_timestamp) = get_block_timestamp();
        let appraisal_post_expiry_date: felt = block_timestamp + nft_appraisal_period + 1;
        let l1_lockup_expiry: felt = appraisal_post_expiry_date + nft_l1_extra_lockup_period;
        assert_le(l1_lockup_expiry, nft_post_expiry);
        _onReceived(
            collection_address,
            from_,
            token_id,
            TRUE,
            appraisal_post_expiry_date,
            nft_debt_period,
            Uint256(1, 0),
        );
        return ();
    }

    func _register_nft{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        collection_address: felt,
        from_: felt,
        token_id: Uint256,
        l1_native: felt,
        appraisal_post_expiry_date: felt,
        nft_debt_period: felt,
        key: Uint256,
    ) {
        alloc_locals;
        let debt_post_expiry_date: felt = appraisal_post_expiry_date + nft_debt_period;
        let (nft_) = nft_listings.read(collection_address, token_id, l1_native);
        assert_uint256_eq(nft_.key, Uint256(0, 0));
        nft_listings.write(
            collection_address,
            token_id,
            l1_native,
            NFT_(from_, appraisal_post_expiry_date, debt_post_expiry_date, key),
        );
        return ();
    }

    func withdraw_nft{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        collection_address: felt, token_id: Uint256
    ) -> (success: felt) {
        alloc_locals;
        let (nft_) = nft_listings.read(collection_address, token_id, FALSE);
        assert_not_zero(nft_.key.low * nft_.key.high);
        let (block_timestamp) = get_block_timestamp();
        assert_le(nft_.appraisal_post_expiry_date, block_timestamp);
        let (caller) = get_caller_address();
        let (key_contract_address) = nft_key_contract_address.read();
        let (owner: felt) = IERC721MintableBurnable.ownerOf(key_contract_address, nft_.key);
        assert owner = caller;
        IERC721MintableBurnable.burn(key_contract_address, token_id);
        let (contract_address: felt) = get_contract_address();
        let (payload: felt*) = alloc();
        IERC721.safeTransferFrom(collection_address, contract_address, owner, token_id, 0, payload);
        return (success=TRUE);
    }

    func _onReceived{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        collection_address: felt,
        from_: felt,
        token_id: Uint256,
        l1_native: felt,
        appraisal_post_expiry_date: felt,
        nft_debt_period: felt,
        key: Uint256,
    ) -> (selector: felt) {
        _register_nft(
            collection_address,
            from_,
            token_id,
            l1_native,
            appraisal_post_expiry_date,
            nft_debt_period,
            key,
        );
        nft_registered.emit(collection_address, token_id, l1_native);
        return (selector=IERC721_RECEIVER_ID);
    }
}
