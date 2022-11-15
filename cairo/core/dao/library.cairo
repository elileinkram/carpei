// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.4.0 (introspection/erc165/library.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_lt, assert_in_range

@storage_var
func nft_appraisal_period() -> (res: felt) {
}

@storage_var
func nft_appraisal_fee() -> (res: felt) {
}

@storage_var
func nft_l1_extra_lockup_period() -> (res: felt) {
}

namespace DAO {
    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        nft_appraisal_period_: felt, nft_l1_extra_lockup_period_: felt, nft_appraisal_fee_: felt
    ) {
        assert_lt(0, nft_appraisal_fee_);
        assert_in_range(2, nft_l1_extra_lockup_period_ + 1, nft_appraisal_period_);
        nft_appraisal_period.write(nft_appraisal_period_);
        nft_l1_extra_lockup_period.write(nft_l1_extra_lockup_period_);
        nft_appraisal_fee.write(nft_appraisal_fee_);
        return ();
    }
}
