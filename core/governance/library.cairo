// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.4.0 (introspection/erc165/library.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_check,
    uint256_eq,
    uint256_lt,
    uint256_sub,
    uint256_add,
)
from starkware.cairo.common.math import (
    assert_not_zero,
    assert_nn_le,
    assert_not_equal,
    assert_lt,
    assert_in_range,
    assert_nn,
    unsigned_div_rem,
)

from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.bool import TRUE, FALSE
from security.safemath.library import SafeUint256

from starkware.starknet.common.syscalls import get_block_timestamp

struct Appraisal {
    appraisal_value: Uint256,
    power_token_amount: Uint256,
}

@storage_var
func nft_appraisals(
    from_: felt, collection_address: felt, token_id: Uint256, appraisal_post_expiry_date: felt
) -> (appraisal: Appraisal) {
}

@storage_var
func nft_appraisal_member_count(
    collection_address: felt, token_id: Uint256, appraisal_post_expiry_date: felt
) -> (vote_count: felt) {
}

@storage_var
func power_token_balances(owner: felt) -> (amount: Uint256) {
}

@storage_var
func power_token_allowances(owner: felt, spender: felt) -> (amount: Uint256) {
}

@storage_var
func nft_funding_period() -> (res: felt) {
}

@storage_var
func nft_appraisal_period() -> (res: felt) {
}

@storage_var
func nft_lockup_period() -> (res: felt) {
}

@storage_var
func min_nft_insurance_period() -> (res: felt) {
}

@storage_var
func nft_median_value(
    collection_address: felt, token_id: Uint256, appraisal_post_expiry_date: felt
) -> (res: Uint256) {
}

@event
func nft_appraised(from_: felt, collection_address: felt, token_id: Uint256) {
}

@event
func nft_median_appraisal_verified(collection_address: felt, token_id: Uint256) {
}

namespace DAO {
    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _nft_lockup_period: felt,
        _nft_appraisal_period: felt,
        _nft_funding_period: felt,
        _min_nft_insurance_period: felt,
    ) {
        assert_nn(_nft_appraisal_period - 1);
        assert_nn(_nft_funding_period - 1);
        assert_nn(_min_nft_insurance_period - 1);
        assert_lt(_nft_appraisal_period + _nft_funding_period, _nft_lockup_period + 1);
        nft_lockup_period.write(_nft_lockup_period);
        nft_appraisal_period.write(_nft_appraisal_period);
        nft_funding_period.write(_nft_funding_period);
        min_nft_insurance_period.write(_min_nft_insurance_period);
        return ();
    }

    func _vote_count_has_changed{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        from_: felt,
        collection_address: felt,
        token_id: Uint256,
        appraisal_post_expiry_date: felt,
        power_token_amount: Uint256,
    ) -> (success: felt, increase_vote: felt) {
        alloc_locals;
        let (old_appraisal: Appraisal) = nft_appraisals.read(
            from_, collection_address, token_id, appraisal_post_expiry_date
        );
        let prev_power_token_amount: Uint256 = old_appraisal.power_token_amount;
        let (prev_token_amount_is_zero) = uint256_eq(prev_power_token_amount, Uint256(0, 0));
        let (token_amount_is_zero) = uint256_eq(power_token_amount, Uint256(0, 0));
        if (prev_token_amount_is_zero == token_amount_is_zero) {
            return (success=FALSE, increase_vote=FALSE);
        }
        return (success=TRUE, increase_vote=prev_token_amount_is_zero);
    }

    func _update_nft_appraisal_member_count{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(
        collection_address: felt,
        token_id: Uint256,
        appraisal_post_expiry_date: felt,
        increase_vote: felt,
    ) {
        let (prev_vote_count) = nft_appraisal_member_count.read(
            collection_address, token_id, appraisal_post_expiry_date
        );
        if (increase_vote == TRUE) {
            nft_appraisal_member_count.write(
                collection_address, token_id, appraisal_post_expiry_date, prev_vote_count + 1
            );
        } else {
            nft_appraisal_member_count.write(
                collection_address, token_id, appraisal_post_expiry_date, prev_vote_count - 1
            );
        }
        return ();
    }

    func _check_power_token_amount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        appraisal_value: Uint256, power_token_amount: Uint256
    ) {
        let (appraisal_is_zero) = uint256_eq(appraisal_value, Uint256(0, 0));
        if (appraisal_is_zero == TRUE) {
            let (power_is_zero) = uint256_eq(power_token_amount, Uint256(0, 0));
            if (power_is_zero == FALSE) {
                assert 0 = 1;
                return ();
            }
            tempvar range_check_ptr = range_check_ptr;
        } else {
            tempvar range_check_ptr = range_check_ptr;
        }
        return ();
    }

    func _appraise_nft{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        from_: felt,
        collection_address: felt,
        token_id: Uint256,
        appraisal_post_expiry_date: felt,
        appraisal_value: Uint256,
        power_token_amount: Uint256,
    ) -> (success: felt) {
        let (has_changed, increase_vote) = _vote_count_has_changed(
            from_, collection_address, token_id, appraisal_post_expiry_date, power_token_amount
        );
        if (has_changed == TRUE) {
            _update_nft_appraisal_member_count(
                collection_address, token_id, appraisal_post_expiry_date, increase_vote
            );
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        } else {
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        }
        nft_appraisals.write(
            from_,
            collection_address,
            token_id,
            appraisal_post_expiry_date,
            Appraisal(appraisal_value, power_token_amount),
        );
        nft_appraised.emit(from_, collection_address, token_id);
        return (success=TRUE);
    }

    func appraise_nft{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        from_: felt,
        collection_address: felt,
        token_id: Uint256,
        appraisal_post_expiry_date: felt,
        appraisal_value: Uint256,
        power_token_amount: Uint256,
    ) -> (success: felt) {
        assert_not_zero(from_);
        uint256_check(token_id);
        uint256_check(appraisal_value);
        uint256_check(power_token_amount);
        let (block_timestamp) = get_block_timestamp();
        assert_lt(block_timestamp, appraisal_post_expiry_date);
        _check_power_token_amount(appraisal_value, power_token_amount);
        let (caller) = get_caller_address();
        return _appraise_nft(
            caller,
            collection_address,
            token_id,
            appraisal_post_expiry_date,
            appraisal_value,
            power_token_amount,
        );
    }

    func _check_sorted_list{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        collection_address: felt,
        token_id: Uint256,
        appraisal_post_expiry_date: felt,
        prev_appraisal_value: Uint256,
        nft_member_appraisals_len: felt,
        nft_member_appraisals: felt*,
    ) {
        let (appraisal) = nft_appraisals.read(
            nft_member_appraisals[0], collection_address, token_id, appraisal_post_expiry_date
        );
        let appraisal_value = appraisal.appraisal_value;
        let (is_less_than_previous_value) = uint256_lt(appraisal_value, prev_appraisal_value);
        if (is_less_than_previous_value == TRUE) {
            assert 0 = 1;
            return ();
        }
        if (nft_member_appraisals_len == 1) {
            return ();
        }
        return _check_sorted_list(
            collection_address,
            token_id,
            appraisal_post_expiry_date,
            appraisal_value,
            nft_member_appraisals_len - 1,
            &nft_member_appraisals[1],
        );
    }

    func _verify_median_appraisal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        index_of_median: felt,
        appraisal_post_expiry_date: felt,
        lockup_post_expiry_date: felt,
        collection_address: felt,
        token_id: Uint256,
        nft_member_appraisals_len: felt,
        nft_member_appraisals: felt*,
    ) -> (success: felt) {
        alloc_locals;
        let (appraisal_1) = nft_appraisals.read(
            nft_member_appraisals[index_of_median],
            collection_address,
            token_id,
            appraisal_post_expiry_date,
        );
        local median_value: Uint256;
        let (_, r) = unsigned_div_rem(nft_member_appraisals_len, 2);
        if (r == 0) {
            let length_constructed_from_median_index = (index_of_median + 1) * 2;
            assert length_constructed_from_median_index = nft_member_appraisals_len;
            let (appraisal_2) = nft_appraisals.read(
                nft_member_appraisals[index_of_median + 1],
                collection_address,
                token_id,
                appraisal_post_expiry_date,
            );
            let sum_of_medians: Uint256 = SafeUint256.add(
                appraisal_1.appraisal_value, appraisal_2.appraisal_value
            );
            let (median_value_, _) = SafeUint256.div_rem(sum_of_medians, Uint256(2, 0));
            assert median_value = median_value_;
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        } else {
            let length_constructed_from_median_index = (index_of_median * 2) + 1;
            assert length_constructed_from_median_index = nft_member_appraisals_len;
            assert median_value = appraisal_1.appraisal_value;
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        }
        nft_median_value.write(
            collection_address, token_id, appraisal_post_expiry_date, median_value
        );
        nft_median_appraisal_verified.emit(collection_address, token_id);
        return (success=TRUE);
    }

    func verify_median_appraisal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        index_of_median: felt,
        appraisal_post_expiry_date: felt,
        lockup_post_expiry_date: felt,
        collection_address: felt,
        token_id: Uint256,
        nft_member_appraisals_len: felt,
        nft_member_appraisals: felt*,
    ) -> (success: felt) {
        assert_not_zero(nft_member_appraisals_len);
        let (block_timestamp) = get_block_timestamp();
        assert_in_range(block_timestamp, appraisal_post_expiry_date - 1, lockup_post_expiry_date);
        let (appraisal_member_count) = nft_appraisal_member_count.read(
            collection_address, token_id, appraisal_post_expiry_date
        );
        assert nft_member_appraisals_len = appraisal_member_count;
        _check_sorted_list(
            collection_address,
            token_id,
            appraisal_post_expiry_date,
            Uint256(1, 0),
            nft_member_appraisals_len,
            nft_member_appraisals,
        );
        return _verify_median_appraisal(
            index_of_median,
            appraisal_post_expiry_date,
            lockup_post_expiry_date,
            collection_address,
            token_id,
            nft_member_appraisals_len,
            nft_member_appraisals,
        );
    }
}
