// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.4.0 (utils/constants/library.cairo)

%lang starknet

//
// Numbers
//

const UINT8_MAX = 255;

//
// Interface Ids
//

// ERC20
const IERC20_ID = 0x36372b07;
const IERC20Metadata_ID = 0xa219a025;

// ERC165
const IERC165_ID = 0x01ffc9a7;
const INVALID_ID = 0xffffffff;
const IACCOUNT_ID = 0xa66bd575;

// ERC721
const IERC721_RECEIVER_ID = 0x150b7a02;
const IERC721_ID = 0x80ac58cd;

//
// Roles
//

const L1_NFT_CONTRACT_ADDRESS = 0x0;
const L1_TOKEN_CONTRACT_ADDRESS = 0x1;

const SEND_FEES_TO_L1_CODE = 0;
const DEPOSIT_TOKEN_L1_CODE = 1;
