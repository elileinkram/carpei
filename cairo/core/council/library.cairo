// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.4.0 (introspection/erc165/library.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_lt

@storage_var
func nft_appraisal_period() -> (res: felt) {
}

@storage_var
func nft_appraisal_fee() -> (res: felt) {
}

namespace Council {
    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        nft_appraisal_period_: felt, nft_appraisal_fee_: felt
    ) {
        assert_lt(0, nft_appraisal_period_);
        assert_lt(0, nft_appraisal_fee_);
        nft_appraisal_period.write(nft_appraisal_period_);
        nft_appraisal_fee.write(nft_appraisal_fee_);
        return ();
    }
}
