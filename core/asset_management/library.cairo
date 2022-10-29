// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.4.0 (introspection/erc165/library.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_check
from starkware.cairo.common.math import assert_not_zero, assert_lt
from utils.constants.library import IERC721_RECEIVER_ID
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_timestamp,
)
from starkware.cairo.common.bool import TRUE
from tokens.erc721.IERC721 import IERC721

struct NFT_ {
    from_: felt,
    insurance_post_expiry_date: felt,
    lockup_post_expiry_date: felt,
    appraisal_post_expiry_date: felt,
}

@storage_var
func nft_listings(collection_address: felt, token_id: Uint256) -> (nft: NFT_) {
}

@event
func nft_registered(collection_address: felt, token_id: Uint256) {
}

namespace NFT {
    func onReceived{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        min_nft_insurance_period: felt,
        from_: felt,
        tokenId: Uint256,
        data_len: felt,
        data: felt*,
        nft_lockup_period: felt,
        nft_appraisal_period: felt,
    ) -> (selector: felt) {
        assert data_len = 1;
        let nft_insurance_period = data[0];
        let (collection_address) = get_caller_address();
        list_nft(
            min_nft_insurance_period,
            nft_insurance_period,
            nft_lockup_period,
            nft_appraisal_period,
            collection_address,
            from_,
            tokenId,
        );
        return (selector=IERC721_RECEIVER_ID);
    }

    func _transfer_nft{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        collection_address: felt, from_: felt, token_id: Uint256
    ) {
        uint256_check(token_id);
        assert_not_zero(collection_address);
        assert_not_zero(from_);
        let (contract_address) = get_contract_address();
        IERC721.transferFrom(collection_address, from_, contract_address, token_id);
        return ();
    }

    func _register_nft{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        nft_insurance_period: felt,
        nft_lockup_period: felt,
        nft_appraisal_period: felt,
        collection_address: felt,
        from_: felt,
        token_id: Uint256,
    ) {
        let (block_timestamp) = get_block_timestamp();
        let lockup_post_expiry_date: felt = block_timestamp + nft_lockup_period + 1;
        let appraisal_post_expiry_date: felt = block_timestamp + nft_appraisal_period + 1;
        let insurance_post_expiry_date: felt = lockup_post_expiry_date + nft_insurance_period;
        let (nft_) = nft_listings.read(collection_address, token_id);
        assert nft_.from_ = 0;
        nft_listings.write(
            collection_address,
            token_id,
            NFT_(from_, insurance_post_expiry_date, lockup_post_expiry_date, appraisal_post_expiry_date,),
        );
        return ();
    }

    func list_nft{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        min_nft_insurance_period: felt,
        nft_insurance_period: felt,
        nft_lockup_period: felt,
        nft_appraisal_period: felt,
        collection_address: felt,
        from_: felt,
        token_id: Uint256,
    ) -> (success: felt) {
        assert_lt(min_nft_insurance_period - 1, nft_insurance_period);
        _transfer_nft(collection_address, from_, token_id);
        _register_nft(
            nft_insurance_period,
            nft_lockup_period,
            nft_appraisal_period,
            collection_address,
            from_,
            token_id,
        );
        nft_registered.emit(collection_address, token_id);
        return (success=TRUE);
    }
}
