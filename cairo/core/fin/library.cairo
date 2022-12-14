// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.4.0 (introspection/erc165/library.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
from starkware.cairo.common.bool import TRUE, FALSE
from security.safemath.library import SafeUint256
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_check,
    uint256_eq,
    uint256_lt,
    assert_uint256_le,
    assert_uint256_eq,
)
from starkware.cairo.common.math import (
    assert_not_zero,
    assert_in_range,
    unsigned_div_rem,
    assert_nn_le,
    assert_lt,
    assert_le,
)
from utils.constants.library import L1_NFT_CONTRACT_ADDRESS, SEND_FEES_TO_L1_CODE
from starkware.starknet.common.messages import send_message_to_l1
from starkware.cairo.common.alloc import alloc

@storage_var
func user_fees(user: felt) -> (res: felt) {
}

@storage_var
func user_fee_delegate(user: felt) -> (res: felt) {
}

@storage_var
func vote_balances(owner: felt) -> (res: felt) {
}

@storage_var
func power_token_balances(owner: felt) -> (amount: Uint256) {
}

@storage_var
func appraisal_token_balances(owner: felt) -> (amount: Uint256) {
}

@storage_var
func appraisal_token_allowances(owner: felt, spender: felt) -> (amount: Uint256) {
}

struct Appraisal {
    appraisal_value: Uint256,
    power_token_amount: Uint256,
}

@storage_var
func nft_appraisals(
    collection_address: felt,
    token_id: Uint256,
    account: felt,
    delegate: felt,
    appraisal_post_expiry_date: felt,
) -> (appraisal: Appraisal) {
}

@storage_var
func nft_appraisal_power_count(
    collection_address: felt, token_id: Uint256, appraisal_post_expiry_date: felt
) -> (power_count: Uint256) {
}

@storage_var
func nft_median_value(
    collection_address: felt, token_id: Uint256, appraisal_post_expiry_date: felt
) -> (res: Uint256) {
}

@event
func nft_appraised(collection_address: felt, from_: felt, token_id: Uint256) {
}

@event
func nft_median_appraisal_verified(collection_address: felt, token_id: Uint256) {
}

namespace FIN {
    func is_approved_or_owner_of_fees{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(caller: felt, owner: felt) -> felt {
        if (owner == caller) {
            return TRUE;
        }
        let (delegate) = user_fee_delegate.read(owner);
        if (delegate == caller) {
            return TRUE;
        }
        return FALSE;
    }

    func is_approved_or_owner_of_appraisal_tokens{
        syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    }(caller: felt, owner: felt, amount: felt) -> felt {
        if (owner == caller) {
            return TRUE;
        }
        let (delegate) = user_fee_delegate.read(owner);
        if (delegate == caller) {
            return TRUE;
        }
        return FALSE;
    }

    func receive_fees_from_l1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        from_: felt, amount: felt
    ) {
        let (deposited) = user_fees.read(from_);

        let increased = deposited + amount;

        assert_lt(deposited, increased);

        user_fees.write(from_, increased);

        return ();
    }

    func transfer_fees_to_l1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        amount: felt
    ) -> (success: felt) {
        let (from_) = get_caller_address();

        assert_lt(0, amount);

        let (deposited) = user_fees.read(from_);

        assert_le(amount, deposited);

        user_fees.write(from_, deposited - amount);

        let (payload: felt*) = alloc();
        assert payload[0] = from_;
        assert payload[1] = amount;
        assert payload[2] = SEND_FEES_TO_L1_CODE;

        send_message_to_l1(L1_NFT_CONTRACT_ADDRESS, 3, payload);
        return (success=TRUE);
    }

    // func _vote_count_has_changed{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    //     collection_address: felt,
    //     token_id: Uint256,
    //     appraiser: felt,
    //     delegate: felt,
    //     appraisal_post_expiry_date: felt,
    //     power_token_amount: Uint256,
    // ) -> (success: felt, increase_vote: felt) {
    //     alloc_locals;
    //     let (old_appraisal: Appraisal) = nft_appraisals.read(
    //         collection_address, token_id, appraiser, delegate, appraisal_post_expiry_date
    //     );
    //     let prev_power_token_amount: Uint256 = old_appraisal.power_token_amount;
    //     let (prev_token_amount_is_zero) = uint256_eq(prev_power_token_amount, Uint256(0, 0));
    //     let (token_amount_is_zero) = uint256_eq(power_token_amount, Uint256(0, 0));
    //     if (prev_token_amount_is_zero == token_amount_is_zero) {
    //         return (success=FALSE, increase_vote=FALSE);
    //     }
    //     return (success=TRUE, increase_vote=prev_token_amount_is_zero);
    // }

    // func _update_nft_appraisal_power_count{
    //     syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
    // }(
    //     collection_address: felt,
    //     token_id: Uint256,
    //     appraisal_post_expiry_date: felt,
    //     increase_vote: felt,
    // ) {
    //     let (prev_vote_count) = nft_appraisal_power_count.read(
    //         collection_address, token_id, appraisal_post_expiry_date
    //     );
    //     if (increase_vote == TRUE) {
    //         nft_appraisal_power_count.write(
    //             collection_address, token_id, appraisal_post_expiry_date, prev_vote_count + 1
    //         );
    //     } else {
    //         nft_appraisal_power_count.write(
    //             collection_address, token_id, appraisal_post_expiry_date, prev_vote_count - 1
    //         );
    //     }
    //     return ();
    // }

    func _check_power_token_amount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        appraisal_value: Uint256, power_token_amount: Uint256
    ) {
        let (appraisal_is_zero) = uint256_eq(appraisal_value, Uint256(0, 0));
        if (appraisal_is_zero == TRUE) {
            assert_uint256_eq(power_token_amount, Uint256(0, 0));
            tempvar range_check_ptr = range_check_ptr;
        } else {
            tempvar range_check_ptr = range_check_ptr;
        }
        return ();
    }

    func approve_appraisal_manager{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        delegate: felt, amount: Uint256
    ) -> (success: felt) {
        let (account) = get_caller_address();
        assert_not_zero(delegate);
        appraisal_token_allowances.write(account, delegate, amount);
        return (success=TRUE);
    }

    func appraise_nft{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        collection_address: felt,
        token_id: Uint256,
        account: felt,
        delegate: felt,
        appraisal_post_expiry_date: felt,
        appraisal_value: Uint256,
        old_power_token_amount: Uint256,
        power_token_amount: Uint256,
    ) -> (success: felt) {
        alloc_locals;
        let (caller) = get_caller_address();
        if (account == caller) {
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        } else {
            let (delegate_balance: Uint256) = appraisal_token_allowances.read(account, delegate);
            assert delegate = caller;
            assert_uint256_le(old_power_token_amount, delegate_balance);
            assert_uint256_le(power_token_amount, delegate_balance);
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        }
        _check_power_token_amount(appraisal_value, power_token_amount);
        let (is_first_time_voter) = uint256_eq(old_power_token_amount, Uint256(0, 0));
        if (is_first_time_voter == TRUE) {
            let (old_number_of_votes: felt) = vote_balances.read(account);
            let new_number_of_votes: felt = old_number_of_votes + 1;
            assert_lt(old_number_of_votes, new_number_of_votes);
            vote_balances.write(account, new_number_of_votes);
            tempvar power_has_increased = TRUE;
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        } else {
            let (has_increased: felt) = uint256_lt(old_power_token_amount, power_token_amount);
            tempvar power_has_increased = has_increased;
            tempvar syscall_ptr = syscall_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar range_check_ptr = range_check_ptr;
        }
        let (old_power_count: Uint256) = nft_appraisal_power_count.read(
            collection_address, token_id, appraisal_post_expiry_date
        );
        if (power_has_increased == TRUE) {
            let (diff: Uint256) = SafeUint256.sub_lt(power_token_amount, old_power_token_amount);
            let (new_power_count: Uint256) = SafeUint256.add(old_power_count, diff);
            nft_appraisal_power_count.write(
                collection_address, token_id, appraisal_post_expiry_date, new_power_count
            );
        } else {
            let (diff: Uint256) = SafeUint256.sub_le(old_power_token_amount, power_token_amount);
            let (new_power_count: Uint256) = SafeUint256.sub_le(old_power_count, diff);
            nft_appraisal_power_count.write(
                collection_address, token_id, appraisal_post_expiry_date, new_power_count
            );
            let (decrement_voter_balance) = uint256_eq(diff, power_token_amount);
            if (decrement_voter_balance == TRUE) {
                let (old_number_of_votes: felt) = vote_balances.read(account);
                let new_number_of_votes: felt = old_number_of_votes - 1;
                vote_balances.write(account, new_number_of_votes);
                tempvar syscall_ptr = syscall_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar range_check_ptr = range_check_ptr;
            } else {
                tempvar syscall_ptr = syscall_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar range_check_ptr = range_check_ptr;
            }
        }
        nft_appraisals.write(
            collection_address,
            token_id,
            account,
            delegate,
            appraisal_post_expiry_date,
            Appraisal(appraisal_value, power_token_amount),
        );
        return (success=TRUE);
    }

    // func _check_sorted_appraisals{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    //     collection_address: felt,
    //     token_id: Uint256,
    //     nft_member_appraisals_len: felt,
    //     nft_member_appraisals: felt*,
    //     prev_appraisal_value: Uint256,
    //     appraisal_post_expiry_date: felt,
    // ) {
    //     let (appraisal) = nft_appraisals.read(
    //         nft_member_appraisals[0], collection_address, token_id, appraisal_post_expiry_date
    //     );
    //     let appraisal_value = appraisal.appraisal_value;
    //     let (is_less_than_previous_value) = uint256_lt(appraisal_value, prev_appraisal_value);
    //     if (is_less_than_previous_value == TRUE) {
    //         assert TRUE = FALSE;
    //         return ();
    //     }
    //     if (nft_member_appraisals_len == 1) {
    //         return ();
    //     }
    //     return _check_sorted_appraisals(
    //         collection_address,
    //         token_id,
    //         nft_member_appraisals_len - 1,
    //         &nft_member_appraisals[1],
    //         appraisal_value,
    //         appraisal_post_expiry_date,
    //     );
    // }

    // func _verify_median_appraisal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    //     index_of_median: felt,
    //     collection_address: felt,
    //     token_id: Uint256,
    //     nft_member_appraisals_len: felt,
    //     nft_member_appraisals: felt*,
    //     appraisal_post_expiry_date: felt,
    //     fundraising_post_expiry_date: felt,
    // ) -> (success: felt) {
    //     alloc_locals;
    //     let (appraisal_1) = nft_appraisals.read(
    //         nft_member_appraisals[index_of_median],
    //         collection_address,
    //         token_id,
    //         appraisal_post_expiry_date,
    //     );
    //     local median_value: Uint256;
    //     let (_, r) = unsigned_div_rem(nft_member_appraisals_len, 2);
    //     if (r == 0) {
    //         let length_constructed_from_median_index = (index_of_median + 1) * 2;
    //         assert length_constructed_from_median_index = nft_member_appraisals_len;
    //         let (appraisal_2) = nft_appraisals.read(
    //             nft_member_appraisals[index_of_median + 1],
    //             collection_address,
    //             token_id,
    //             appraisal_post_expiry_date,
    //         );
    //         let sum_of_medians: Uint256 = SafeUint256.add(
    //             appraisal_1.appraisal_value, appraisal_2.appraisal_value
    //         );
    //         let (median_value_, _) = SafeUint256.div_rem(sum_of_medians, Uint256(2, 0));
    //         assert median_value = median_value_;
    // tempvar syscall_ptr = syscall_ptr;
    // tempvar pedersen_ptr = pedersen_ptr;
    // tempvar range_check_ptr = range_check_ptr;
    //     } else {
    //         let length_constructed_from_median_index = (index_of_median * 2) + 1;
    //         assert length_constructed_from_median_index = nft_member_appraisals_len;
    //         assert median_value = appraisal_1.appraisal_value;
    //         tempvar syscall_ptr = syscall_ptr;
    //         tempvar pedersen_ptr = pedersen_ptr;
    //         tempvar range_check_ptr = range_check_ptr;
    //     }
    //     nft_median_value.write(
    //         collection_address, token_id, appraisal_post_expiry_date, median_value
    //     );
    //     nft_median_appraisal_verified.emit(collection_address, token_id);
    //     return (success=TRUE);
    // }

    // func verify_median_appraisal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    //     index_of_median: felt,
    //     collection_address: felt,
    //     token_id: Uint256,
    //     nft_member_appraisals_len: felt,
    //     nft_member_appraisals: felt*,
    //     appraisal_post_expiry_date: felt,
    //     fundraising_post_expiry_date: felt,
    // ) -> (success: felt) {
    //     let (block_timestamp) = get_block_timestamp();
    //     assert_in_range(block_timestamp, appraisal_post_expiry_date, fundraising_post_expiry_date);
    //     let (appraisal_member_count) = nft_appraisal_power_count.read(
    //         collection_address, token_id, appraisal_post_expiry_date
    //     );
    //     assert_not_zero(appraisal_member_count);
    //     assert appraisal_member_count = nft_member_appraisals_len;
    //     assert_nn_le(index_of_median, appraisal_member_count - 1);
    //     _check_sorted_appraisals(
    //         collection_address,
    //         token_id,
    //         nft_member_appraisals_len,
    //         nft_member_appraisals,
    //         Uint256(1, 0),
    //         appraisal_post_expiry_date,
    //     );
    //     return _verify_median_appraisal(
    //         index_of_median,
    //         collection_address,
    //         token_id,
    //         nft_member_appraisals_len,
    //         nft_member_appraisals,
    //         appraisal_post_expiry_date,
    //         fundraising_post_expiry_date,
    //     );
    // }
}
