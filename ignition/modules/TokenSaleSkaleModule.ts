import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "viem";

const TokenSaleSkaleModule = buildModule("TokenSaleSkaleModule", (m) => {
  const swapRouter = m.getParameter("swapRouter");
  const factory = m.getParameter("factory");
  const usdt = m.getParameter("usdt");
  const treasury = m.getParameter("treasury");
  const usdtCap = parseEther("30000");

  // Deploy TokenSale
  const tokenSale = m.contract("TokenSaleSkale", [
    swapRouter,
    factory,
    usdt,
    treasury,
    usdtCap,
  ]);

  return { tokenSale };
});

export default TokenSaleSkaleModule;
