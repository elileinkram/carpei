// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "../utils/introspection/ERC165.sol";
import "../token/ERC721/IERC721Receiver.sol";
import "../token/ERC721/ERC721.sol";
import "../token/ERC721/IERC721.sol";
import "./starknet/IStarknetMessaging.sol";
import "../token/ERC20/presets/ERC20StarkMessenger.sol";

contract Carpei is IERC721Receiver, ERC165, ERC721 {
    mapping(bytes32 => NFT) public nonFungibles;
    mapping(address => uint256) public userFees;
    mapping(address => address) public managerOf;
    struct NFT {
        uint256 key;
        uint256 postExpiry;
        uint256 appraisalFee;
        bool isAppraised;
    }

    ERC20StarkMessenger public immutable ERC20_MESSENGER;

    uint256 public nonce;

    uint256 public immutable SELECTOR_STARK_INITIATE_APPRAISAL =
        _selectorStarkNet("onERC721ReceivedFromL1");

    uint256 public immutable SELECTOR_STARK_RECEIVE_L1_FEES =
        _selectorStarkNet("receive_fees_from_l1");

    IStarknetMessaging public immutable STARKNET_CROSS_DOMAIN_MESSENGER;
    uint256 public immutable L2_RECEIVER;
    uint256 public constant RECEIVE_FEES_FROM_L2_CODE = 0;
    uint256 public constant felt_upper_bound = 2**252;

    constructor(
        string memory name,
        string memory symbol,
        address starknetMessaging,
        uint256 l2Receiver
    ) {
        require(starknetMessaging != address(0));
        require(l2Receiver != 0);
        STARKNET_CROSS_DOMAIN_MESSENGER = IStarknetMessaging(starknetMessaging);
        L2_RECEIVER = l2Receiver;
        ERC20_MESSENGER = new ERC20StarkMessenger(
            name,
            symbol,
            starknetMessaging,
            l2Receiver
        );
    }

    function approveFeeManager(address delegate) public returns (bool) {
        require(delegate != address(0));
        managerOf[msg.sender] = delegate;
        return true;
    }

    function depositFees(address recipient) public payable returns (bool) {
        require(recipient != address(0));
        userFees[recipient] += msg.value;
        require(userFees[recipient] < felt_upper_bound);
        return true;
    }

    function receiveFeesFromL2(address recipient, uint256 amount)
        public
        returns (bool)
    {
        uint256[] memory payload = new uint256[](3);
        payload[0] = _uint256Addr(recipient);
        payload[1] = amount;
        payload[2] = RECEIVE_FEES_FROM_L2_CODE;
        STARKNET_CROSS_DOMAIN_MESSENGER.consumeMessageFromL2(
            L2_RECEIVER,
            payload
        );
        userFees[recipient] += amount;
        return true;
    }

    function transferFeesToL2(uint256 amount) public payable returns (bool) {
        _decreaseMyFeeBalance(amount);
        uint256[] memory payload = new uint256[](2);
        payload[0] = _uint256Addr(msg.sender);
        payload[1] = amount;
        STARKNET_CROSS_DOMAIN_MESSENGER.sendMessageToL2{value: msg.value}(
            L2_RECEIVER,
            SELECTOR_STARK_RECEIVE_L1_FEES,
            payload
        );
        return true;
    }

    function withdrawFees(uint256 amount) public payable returns (bool) {
        _decreaseMyFeeBalance(amount);
        payable(msg.sender).transfer(amount);
        return true;
    }

    function _decreaseMyFeeBalance(uint256 amount) private {
        require(amount != 0);
        require(amount <= userFees[msg.sender]);
        userFees[msg.sender] -= amount;
    }

    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        bytes32 nftHash = keccak256(abi.encode(msg.sender, tokenId));
        NFT storage nft = nonFungibles[nftHash];
        require(nft.key == 0);
        nonce += 1;
        nft.key = nonce;
        _safeMint(from, nonce);
        (
            uint256 debtPeriod,
            uint256 lockupPeriod,
            uint256 postageFee,
            uint256 appraisalFee
        ) = abi.decode(data, (uint256, uint256, uint256, uint256));
        require(debtPeriod & lockupPeriod & postageFee & appraisalFee != 0);
        uint256 totalCost = postageFee + appraisalFee;
        require(msg.sender == managerOf[from] || msg.sender == from);
        uint256 availableFees = userFees[from];
        require(availableFees >= totalCost);
        userFees[from] = availableFees - totalCost;
        nft.postExpiry = block.timestamp + lockupPeriod + 1;
        uint256[] memory payload = new uint256[](7);
        payload[0] = _uint256Addr(msg.sender);
        payload[1] = _uint256Addr(from);
        payload[2] = get_low_n_bits(tokenId, 128);
        payload[3] = get_high_n_bits(tokenId, 128);
        payload[4] = appraisalFee;
        payload[5] = debtPeriod;
        payload[6] = nft.postExpiry;
        STARKNET_CROSS_DOMAIN_MESSENGER.sendMessageToL2{value: postageFee}(
            L2_RECEIVER,
            SELECTOR_STARK_INITIATE_APPRAISAL,
            payload
        );
        return this.onERC721Received.selector;
    }

    function get_low_n_bits(uint256 x, uint256 n)
        internal
        pure
        returns (uint256)
    {
        uint256 mask = (1 << n) - 1;
        return x & mask;
    }

    function get_high_n_bits(uint256 x, uint256 n)
        internal
        pure
        returns (uint256)
    {
        return x >> n;
    }

    function withdrawNFT(address collection, uint256 tokenId)
        public
        returns (bool)
    {
        bytes32 nftHash = keccak256(abi.encode(collection, tokenId));
        NFT storage nft = nonFungibles[nftHash];
        require(nft.postExpiry <= block.timestamp);
        uint256 key = nft.key;
        address owner = ownerOf(key);
        require(owner != address(0));
        require(owner == msg.sender);
        delete nft.key;
        super._burn(key);
        if (!nft.isAppraised) {
            userFees[owner] += nft.appraisalFee;
            nft.appraisalFee = 0;
        } else {
            nft.isAppraised = false;
        }
        IERC721(collection).safeTransferFrom(address(this), owner, tokenId);
        return true;
    }

    function _selectorStarkNet(string memory fn)
        internal
        pure
        returns (uint256)
    {
        bytes32 digest = keccak256(abi.encodePacked(fn));
        return uint256(digest) % 2**250;
    }

    function _uint256Addr(address addr) internal pure returns (uint256) {
        return uint256(uint160(addr));
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165, ERC721)
        returns (bool)
    {
        return
            interfaceId == type(IERC721Receiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
