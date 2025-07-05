# BossFi 比特币质押合约文档

## 合约简介
BossFiBTCStaking 合约允许用户质押主流比特币类资产（如 WBTC、FBTC 等），获得收据代币（bBTC）和积分奖励。积分可用于后续 Boss Token 空投。

- 支持多种 BTC 资产（可扩展）
- 质押获得收据代币（bBTC），可随时查询和转让
- 按天累计积分，积分可领取
- 支持正常解质押和即时解质押
- 管理员可设置支持的资产、操作员、质押上限等

## 支持的代币
合约支持多种 BTC 资产，管理员可动态添加/移除。初始建议支持：
- WBTC（Wrapped BTC，8位小数）
- FBTC（Fake BTC，8位小数）
- 其他兼容ERC20、8位小数的BTC资产

## 收据代币（bBTC）
- 每质押1 satoshi（0.00000001 BTC）获得1 bBTC
- bBTC 可转让、查询余额
- 解质押时销毁相应 bBTC

## 积分与空投
- 每天每质押1 satoshi 获得1积分
- 用户可随时领取积分（claimPoints）
- 积分用于后续 Boss Token 空投奖励

## 主要接口说明

### 管理员/操作员接口
- `addSupportedToken(address token, uint8 decimals)`：添加支持的BTC资产
- `removeSupportedToken(address token)`：移除支持的BTC资产
- `setStakeAssetCap(uint256 cap)`：设置质押上限
- `setOperator(address)`：设置操作员
- `pause()/unpause()`：暂停/恢复合约

### 用户接口
- `stake(address token, uint256 amount)`：质押BTC资产，获得bBTC
- `unstakeRequest(uint256 amount)`：发起解质押请求，销毁bBTC
- `claimSlot(uint8 slot)`：领取指定槽位的解质押资产
- `claimAll()`：一次性领取所有可领取的解质押资产
- `unstakeInstant(uint256 amount)`：即时解质押，收取3%手续费
- `claimPoints()`：领取积分
- `getUserInfo(address)`：查询用户质押、积分等信息
- `getUserUnstakeInfo(address, uint8 slot)`：查询用户解质押请求信息

## 积分规则
- 质押期间，每天每1 bBTC（1 satoshi）获得1积分
- 领取积分时自动结算到用户积分余额
- 领取后积分归零，重新累计

## 安全性
- 采用OpenZeppelin库，安全可靠
- 管理员可暂停合约，防止紧急风险
- 仅支持白名单资产，防止钓鱼代币

## 未来扩展
- 支持更多BTC资产
- Boss Token空投积分兑换
- 前端集成与数据看板

---
如需更多帮助，请联系BossFi开发团队。 