pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/ITokenSale.sol";
import "./helpers/TransferHelper.sol";

contract PrivateSale is Ownable, ReentrancyGuard, Pausable, ITokenSale {
  using SafeMath for uint256;
  using Address for address;

  address public immutable token;
  address public immutable saleCreator;
  address public immutable proceedsTo;
  address public immutable admin;

  uint256 public tokensAvailableForSale;
  uint256 public immutable tokensPerEther;
  uint256 public immutable softcap;
  uint256 public immutable hardcap;
  uint256 public immutable saleStartTime;
  uint256 public immutable saleEndTime;
  uint256 public immutable minContribution;
  uint256 public immutable maxContribution;

  uint8 public saleCreatorPercentage;

  bool public isSaleEnded;

  mapping(address => uint256) public balances;
  mapping(address => uint256) public amountContributed;
  mapping(address => bool) public isBanned;
  mapping(address => bool) public isWhitelisted;

  SaleType public constant saleType = SaleType.PRIVATE_REGULAR;

  modifier ifParamsSatisfied() {
    require(block.timestamp >= saleStartTime, "token_sale_not_started_yet");
    require(!isSaleEnded, "token_sale_has_ended");
    require(isWhitelisted[_msgSender()], "only_whitelisted_addresses_can_take_part_in_this_sale");
    require(!isBanned[_msgSender()], "you_are_not_allowed_to_participate_in_this_sale");
    require(address(this).balance < hardcap, "hardcap_reached");
    _;
  }

  constructor(
    address _token,
    address _proceedsTo,
    uint256 _tokensAvailableForSale,
    uint256 _softcap,
    uint256 _hardcap,
    uint256 _tokensPerEther,
    uint256 _saleStartTime,
    uint256 _saleEndTime,
    uint8 _saleCreatorPercentage,
    uint256 _minContribution,
    uint256 _maxContribution,
    address _admin,
    address[] memory whitelist
  ) {
    token = _token;
    saleCreator = _msgSender();
    proceedsTo = _proceedsTo;
    tokensAvailableForSale = _tokensAvailableForSale;
    softcap = _softcap;
    hardcap = _hardcap;
    tokensPerEther = _tokensPerEther;
    saleStartTime = _saleStartTime;
    saleEndTime = _saleEndTime;
    saleCreatorPercentage = _saleCreatorPercentage;
    minContribution = _minContribution;
    maxContribution = _maxContribution;
    admin = _admin;
    _transferOwnership(_admin);

    for (uint256 i = 0; i < whitelist.length; i++) _switchWhitelistAddress(whitelist[i]);
  }

  function contribute() external payable nonReentrant whenNotPaused ifParamsSatisfied {
    require(msg.value >= minContribution && msg.value <= maxContribution, "contribution_must_be_within_min_and_max_range");
    uint256 val = tokensPerEther.mul(msg.value).div(1 ether);
    require(tokensAvailableForSale >= val, "tokens_available_for_sale_is_less");
    balances[_msgSender()] = balances[_msgSender()].add(val);
    amountContributed[_msgSender()] = amountContributed[_msgSender()].add(msg.value);
    tokensAvailableForSale = tokensAvailableForSale.sub(val);
  }

  function withdraw() external whenNotPaused nonReentrant {
    require(!isSaleEnded || block.timestamp >= saleEndTime, "sale_has_not_ended");
    TransferHelpers._safeTransferERC20(token, _msgSender(), balances[_msgSender()]);
    delete balances[_msgSender()];
  }

  function emergencyWithdraw() external nonReentrant {
    require(!isSaleEnded, "sale_has_already_ended");
    TransferHelpers._safeTransferEther(_msgSender(), amountContributed[_msgSender()]);
    tokensAvailableForSale = tokensAvailableForSale.add(balances[_msgSender()]);
    delete balances[_msgSender()];
    delete amountContributed[_msgSender()];
  }

  function finalizeSale() external whenNotPaused onlyOwner {
    require(!isSaleEnded, "sale_has_ended");
    uint256 saleCreatorProfit = (address(this).balance * uint256(saleCreatorPercentage)).div(100);
    TransferHelpers._safeTransferEther(proceedsTo, address(this).balance.sub(saleCreatorProfit));
    TransferHelpers._safeTransferEther(saleCreator, saleCreatorProfit);

    if (tokensAvailableForSale > 0) {
      TransferHelpers._safeTransferERC20(token, proceedsTo, tokensAvailableForSale);
    }

    isSaleEnded = true;
  }

  function retrieveERC20(
    address _token,
    address _to,
    uint256 _amount
  ) external onlyOwner {
    require(_token.isContract(), "must_be_contract_address");
    TransferHelpers._safeTransferERC20(_token, _to, _amount);
  }

  function switchBanAddress(address account) external onlyOwner {
    isBanned[account] = !isBanned[account];
  }

  function _switchWhitelistAddress(address account) private {
    isWhitelisted[account] = !isWhitelisted[account];
  }

  function switchWhitelistAddress(address account) public onlyOwner {
    _switchWhitelistAddress(account);
  }
}
