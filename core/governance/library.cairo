// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.4.0 (introspection/erc165/library.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_lt, assert_nn
from starkware.cairo.common.uint256 import Uint256

@storage_var
func power_token_balances(owner: felt) -> (amount: Uint256) {
}

@storage_var
func power_token_allowances(owner: felt, spender: felt) -> (amount: Uint256) {
}

@storage_var
func nft_fundraising_period() -> (res: felt) {
}

@storage_var
func nft_appraisal_period() -> (res: felt) {
}

@storage_var
func nft_lockup_period() -> (res: felt) {
}

namespace DAO {
    func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        _nft_lockup_period: felt, _nft_appraisal_period: felt, _nft_fundraising_period: felt
    ) {
        assert_nn(_nft_appraisal_period - 1);
        assert_nn(_nft_fundraising_period - 1);
        assert_lt(_nft_appraisal_period + _nft_fundraising_period, _nft_lockup_period + 1);
        nft_lockup_period.write(_nft_lockup_period);
        nft_appraisal_period.write(_nft_appraisal_period);
        nft_fundraising_period.write(_nft_fundraising_period);
        return ();
    }
}
