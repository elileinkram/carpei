// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.4.0 (introspection/erc165/library.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from utils.constants.library import IERC721_RECEIVER_ID
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_timestamp,
)
from starkware.cairo.common.bool import TRUE, FALSE
from tokens.erc721.IERC721 import IERC721
from starkware.cairo.common.uint256 import Uint256, uint256_check
from starkware.cairo.common.math import assert_not_zero, assert_nn_le

struct NFT_ {
    from_: felt,
    underwriting_post_expiry_date: felt,
    fundraising_post_expiry_date: felt,
    appraisal_post_expiry_date: felt,
}

@storage_var
func nft_listings(collection_address: felt, token_id: Uint256) -> (nft: NFT_) {
}

@event
func nft_registered(collection_address: felt, token_id: Uint256) {
}

namespace Gallery {
    func onReceived{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        from_: felt,
        tokenId: Uint256,
        data_len: felt,
        data: felt*,
        nft_appraisal_period: felt,
        nft_fundraising_period: felt,
    ) -> (selector: felt) {
        assert TRUE = data_len;
        let nft_underwriting_period = data[0];
        assert_nn_le(nft_appraisal_period + nft_fundraising_period, nft_underwriting_period);
        let (collection_address) = get_caller_address();
        return _onReceived(
            nft_appraisal_period,
            nft_fundraising_period,
            nft_underwriting_period,
            collection_address,
            from_,
            tokenId,
        );
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
        nft_appraisal_period: felt,
        nft_fundraising_period: felt,
        nft_underwriting_period: felt,
        collection_address: felt,
        from_: felt,
        token_id: Uint256,
    ) {
        let (block_timestamp) = get_block_timestamp();
        let appraisal_post_expiry_date: felt = block_timestamp + nft_appraisal_period + 1;
        let fundraising_post_expiry_date: felt = appraisal_post_expiry_date + nft_fundraising_period;
        let underwriting_post_expiry_date: felt = fundraising_post_expiry_date + nft_underwriting_period;
        let (nft_) = nft_listings.read(collection_address, token_id);
        assert FALSE = nft_.from_;
        nft_listings.write(
            collection_address,
            token_id,
            NFT_(from_, underwriting_post_expiry_date, fundraising_post_expiry_date, appraisal_post_expiry_date),
        );
        return ();
    }

    func _onReceived{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        nft_appraisal_period: felt,
        nft_fundraising_period: felt,
        nft_underwriting_period: felt,
        collection_address: felt,
        from_: felt,
        token_id: Uint256,
    ) -> (selector: felt) {
        _transfer_nft(collection_address, from_, token_id);
        _register_nft(
            nft_appraisal_period,
            nft_fundraising_period,
            nft_underwriting_period,
            collection_address,
            from_,
            token_id,
        );
        nft_registered.emit(collection_address, token_id);
        return (selector=IERC721_RECEIVER_ID);
    }
}
