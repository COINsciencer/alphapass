//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract AlphaNft is Ownable, ERC721A, ReentrancyGuard {
    uint256 public immutable maxQty = 1024;
    uint256 public _tokensReserved;
    uint256 public _mintPrice;
    uint256 public immutable maxMintPerAddr = 2;
    string private _baseTokenURI;

    //sale stages:
    //stage 0: init(no minting, only reserve)mint 24
    //stage 1: whitelist mint+ public mint
    //stage 2: whitelist mint + team mint + public mint
    //stage 3: only reserve
    uint8 public _stage = 0;
    uint256 public immutable maxQtyStage1 = 300;
    uint256 public immutable maxQtyStage2 = 700;
    uint256 public _tokensMintedStage1 = 0;
    uint256 public _tokensMintedStage2 = 0;
    bool public _isPublicMintOpen = false;

    constructor(string memory baseURI)
        ERC721A("AlphaSciPass", "AlphaSciPass")
    {
        _baseTokenURI = baseURI;
    }

    function nextStage(uint256 nextStageMintPrice) external onlyOwner {
        require(_stage <= 3, "Stage cannot be more than 3");
        _stage++;
        _mintPrice = nextStageMintPrice;
        _isPublicMintOpen = false;
    }

    function setMintPrice(uint256 mintPrice) external onlyOwner {
        
        _mintPrice = mintPrice;
    }

    function setIsPublicMintOpen(bool isPublicMintOpen) external onlyOwner {
        _isPublicMintOpen = isPublicMintOpen;
    }

    function reserve(address recipient, uint256 quantity) external onlyOwner {
        require(quantity > 0, "Quantity too low");
        uint256 totalsupply = totalSupply();
        require(totalsupply + quantity <= maxQty, "Exceed sales max limit");

        _safeMint(recipient, quantity);
        _tokensReserved += quantity;  
    }

    function whitelistMint(uint256 quantity, bytes memory signature) external payable nonReentrant {
        require(_stage == 1 || _stage == 2 , "invalid stage");
        require(isStageMaxQtyExceed(quantity), "Exceed stage sales max limit");

        require(verify(signature, _msgSender()), "Verify failed");

        require(tx.origin == msg.sender, "Contracts not allowed");
        uint256 totalsupply = totalSupply();
        require(totalsupply + quantity <= maxQty, "Exceed sales max limit");
        require(
            numberMinted(msg.sender) + quantity <= maxMintPerAddr,
            "cannot mint this many"
        );

        uint256 cost;
        unchecked {
            cost = quantity * _mintPrice;
        }
        require(msg.value == cost, "wrong payment");

        _safeMint(msg.sender, quantity);
        increaseTokensMinted(quantity);
  
    }

    function mint(uint256 quantity) external payable nonReentrant {
        require(_stage == 1 || _stage == 2, "invalid stage");
        require(isStageMaxQtyExceed(quantity), "Exceed stage sales max limit");
        
        require(_isPublicMintOpen, "public sales not opening");

        require(tx.origin == msg.sender, "Contracts not allowed");
        uint256 totalsupply = totalSupply();
        require(totalsupply + quantity <= maxQty, "Exceed sales max limit");
        require(
            numberMinted(msg.sender) + quantity <= maxMintPerAddr,
            "cannot mint this many"
        );

        uint256 cost;
        unchecked {
            cost = quantity * _mintPrice;
        } 
        require(msg.value == cost, "wrong payment");

        _safeMint(msg.sender, quantity);
        increaseTokensMinted(quantity);
    
    }

    function verify(bytes memory signature, address target) internal view returns (bool) {
        bytes32 message = keccak256(
            abi.encodePacked(target, _stage)
        );

        bytes32 messageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", message)
        );

        return owner() == ECDSA.recover(messageHash, signature);
    }

    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function isStageMaxQtyExceed(uint256 quantity) internal view returns (bool) {
        if (_stage == 1) {
            return _tokensMintedStage1 + quantity <= maxQtyStage1;
        }
        if (_stage == 2) {
            return _tokensMintedStage2 + quantity <= maxQtyStage2;
        }
        return false;
    }

    function increaseTokensMinted(uint256 quantity) internal {
        if (_stage == 1) {
            _tokensMintedStage1 += quantity;
        }
        if (_stage == 2) {
            _tokensMintedStage2 += quantity;
        }
    }

    function withdraw() external nonReentrant onlyOwner {
        uint256 balance = address(this).balance;
        (bool success1, ) = payable(_msgSender()).call{ value: balance }("");
        require(success1, "Transfer failed.");
    }



}
