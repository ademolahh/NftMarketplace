// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestERC721 is ERC721 {
    uint256 tokenId;

    constructor() ERC721("GameItem", "ITM") {
        mint(msg.sender, 5);
        mint(0x70997970C51812dc3A010C7d01b50e0d17dc79C8, 5);
    }

    function mint(address account, uint256 amount) internal {
        uint256 id = tokenId;
        uint256 i;
        for (; i < amount; ) {
            _mint(account, id + i);
            unchecked {
                ++i;
            }
        }
        id += amount;
        tokenId = id;
    }
}
