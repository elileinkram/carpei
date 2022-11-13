// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.4.0 (introspection/erc165/library.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from utils.constants.library import IERC721_RECEIVER_ID
from starkware.starknet.common.syscalls import get_contract_address, get_block_timestamp
from tokens.erc721.IERC721 import IERC721
from starkware.cairo.common.uint256 import Uint256, uint256_check
from starkware.cairo.common.math import assert_not_zero, assert_le
from starkware.cairo.common.bool import TRUE, FALSE

struct NFT_ {
    from_: felt,
    appraisal_post_expiry_date: felt,
    debt_post_expiry_date: felt,
}

@storage_var
func nft_listings(collection_address: felt, token_id: Uint256, l1_native: felt) -> (nft: NFT_) {
}

@event
func nft_registered(collection_address: felt, token_id: Uint256, l1_native: felt) {
}

namespace Gallery {
    func onReceivedFromL2{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        collection_address: felt,
        from_: felt,
        tokenId: Uint256,
        data_len: felt,
        data: felt*,
        nft_appraisal_period: felt,
    ) -> (selector: felt) {
        assert 1 = data_len;
        let nft_debt_period = data[0];
        assert_lt(nft_appraisal_period, nft_debt_period);
        let (block_timestamp) = get_block_timestamp();
        let appraisal_post_expiry_date: felt = block_timestamp + nft_appraisal_period + 1;
        return _onReceived(
            collection_address, from_, tokenId, FALSE, appraisal_post_expiry_date, nft_debt_period
        );
    }

    func onReceivedFromL1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        collection_address: felt,
        from_: felt,
        token_id: Uint256,
        nft_appraisal_period: felt,
        appraisal_fee: felt,
        nft_appraisal_fee: felt,
        nft_debt_period: felt,
        nft_post_expiry: felt,
    ) {
        assert_lt(nft_appraisal_period, nft_debt_period);
        assert_le(nft_appraisal_fee, appraisal_fee);
        let (block_timestamp) = get_block_timestamp();
        let appraisal_post_expiry_date: felt = block_timestamp + nft_appraisal_period + 1;
        assert_le(appraisal_post_expiry_date, nft_post_expiry);
        _onReceived(
            collection_address, from_, token_id, TRUE, appraisal_post_expiry_date, nft_debt_period
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
    ) {
        let debt_post_expiry_date: felt = appraisal_post_expiry_date + nft_debt_period;
        let (nft_) = nft_listings.read(collection_address, token_id, l1_native);
        assert 0 = nft_.from_;
        nft_listings.write(
            collection_address,
            token_id,
            l1_native,
            NFT_(from_, appraisal_post_expiry_date, debt_post_expiry_date,),
        );
        return ();
    }

    func _onReceived{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        collection_address: felt,
        from_: felt,
        token_id: Uint256,
        l1_native: felt,
        appraisal_post_expiry_date: felt,
        nft_debt_period: felt,
    ) -> (selector: felt) {
        _register_nft(
            collection_address,
            from_,
            token_id,
            l1_native,
            appraisal_post_expiry_date,
            nft_debt_period,
        );
        nft_registered.emit(collection_address, token_id, l1_native);
        return (selector=IERC721_RECEIVER_ID);
    }
}
