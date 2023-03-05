pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./helpers/TransferHelper.sol";
import "./misc/VestingSchedule.sol";
import "./misc/SaleInfo.sol";
import "./PrivateSale.sol";
import "./PrivateSaleVestable.sol";

contract PrivateTokenSaleCreator is ReentrancyGuard, Pausable, Ownable, AccessControl {
  using Address for address;
  using SafeMath for uint256;

  bytes32 public withdrawerRole = keccak256(abi.encodePacked("WITHDRAWER_ROLE"));

  uint8 public feePercentage;
  uint256 public saleCreationFee;

  event TokenSaleItemCreated(
    address privateSaleAddress,
    address token,
    uint256 tokensForSale,
    uint256 softcap,
    uint256 hardcap,
    uint256 tokensPerEther,
    uint256 minContributionEther,
    uint256 maxContributionEther,
    uint256 saleStartTime,
    uint256 saleEndTime,
    address proceedsTo,
    address admin
  );

  constructor(uint8 _feePercentage, uint256 _saleCreationFee) {
    _grantRole(withdrawerRole, _msgSender());
    feePercentage = _feePercentage;
    saleCreationFee = _saleCreationFee;
  }

  function createPrivateSale(PrivateSaleInfo memory saleInfo, string memory metadataURI)
    external
    payable
    whenNotPaused
    nonReentrant
    returns (address privateSaleAddress)
  {
    uint256 endTime = saleInfo.saleStartTime.add(uint256(saleInfo.daysToLast) * 1 days);

    {
      require(msg.value >= saleCreationFee, "fee");
      require(saleInfo.token.isContract(), "must_be_contract_address");
      require(
        saleInfo.saleStartTime > block.timestamp && saleInfo.saleStartTime.sub(block.timestamp) >= 24 hours,
        "sale_must_begin_in_at_least_24_hours"
      );
    }

    {
      bytes memory bytecode = abi.encodePacked(type(PrivateSale).creationCode, abi.encode(saleInfo, feePercentage, metadataURI));
      bytes32 salt = keccak256(abi.encodePacked(block.timestamp, address(this), saleInfo.admin, saleInfo.token));

      assembly {
        privateSaleAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
        if iszero(extcodesize(privateSaleAddress)) {
          revert(0, 0)
        }
      }
      require(IERC20(saleInfo.token).allowance(_msgSender(), address(this)) >= saleInfo.tokensForSale, "not_enough_allowance_given");
      TransferHelpers._safeTransferFromERC20(saleInfo.token, _msgSender(), privateSaleAddress, saleInfo.tokensForSale);
    }

    {
      emit TokenSaleItemCreated(
        privateSaleAddress,
        saleInfo.token,
        saleInfo.tokensForSale,
        saleInfo.softcap,
        saleInfo.hardcap,
        saleInfo.tokensPerEther,
        saleInfo.minContributionEther,
        saleInfo.maxContributionEther,
        saleInfo.saleStartTime,
        endTime,
        saleInfo.proceedsTo,
        saleInfo.admin
      );
    }
  }

  function createPrivateSaleVestable(
    PrivateSaleInfo memory saleInfo,
    VestingSchedule[] memory vestingSchedule,
    string memory metadataURI
  ) external payable whenNotPaused nonReentrant returns (address privateSaleAddress) {
    uint256 endTime = saleInfo.saleStartTime.add(uint256(saleInfo.daysToLast) * 1 days);

    {
      require(msg.value >= saleCreationFee, "fee");
      require(saleInfo.token.isContract(), "must_be_contract_address");
      require(
        saleInfo.saleStartTime > block.timestamp && saleInfo.saleStartTime.sub(block.timestamp) >= 24 hours,
        "sale_must_begin_in_at_least_24_hours"
      );
    }

    {
      string memory mDataURI = metadataURI;
      bytes memory bytecode = abi.encodePacked(
        type(PrivateSaleVestable).creationCode,
        abi.encode(saleInfo, feePercentage, vestingSchedule, mDataURI)
      );
      bytes32 salt = keccak256(abi.encodePacked(block.timestamp, address(this), saleInfo.admin, saleInfo.token));

      assembly {
        privateSaleAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
        if iszero(extcodesize(privateSaleAddress)) {
          revert(0, 0)
        }
      }
      require(IERC20(saleInfo.token).allowance(_msgSender(), address(this)) >= saleInfo.tokensForSale, "not_enough_allowance_given");
      TransferHelpers._safeTransferFromERC20(saleInfo.token, _msgSender(), privateSaleAddress, saleInfo.tokensForSale);
    }

    {
      emit TokenSaleItemCreated(
        privateSaleAddress,
        saleInfo.token,
        saleInfo.tokensForSale,
        saleInfo.softcap,
        saleInfo.hardcap,
        saleInfo.tokensPerEther,
        saleInfo.minContributionEther,
        saleInfo.maxContributionEther,
        saleInfo.saleStartTime,
        endTime,
        saleInfo.proceedsTo,
        saleInfo.admin
      );
    }
  }

  function withdrawEther(address to) external {
    require(hasRole(withdrawerRole, _msgSender()) || _msgSender() == owner(), "only_withdrawer_or_owner");
    TransferHelpers._safeTransferEther(to, address(this).balance);
  }

  function retrieveERC20(
    address _token,
    address _to,
    uint256 _amount
  ) external onlyOwner {
    require(_token.isContract(), "must_be_contract_address");
    TransferHelpers._safeTransferERC20(_token, _to, _amount);
  }

  function setFeePercentage(uint8 _feePercentage) external onlyOwner {
    feePercentage = _feePercentage;
  }

  function setSaleCreationFee(uint256 _saleCreationFee) external onlyOwner {
    saleCreationFee = _saleCreationFee;
  }

  receive() external payable {}
}
