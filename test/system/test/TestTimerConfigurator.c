#include "unity.h"
#include "Types.h"
#include "TimerConfigurator.h"
#include "AT91SAM7X256.h"
#include "MockTimerInterruptConfigurator.h"

AT91S_PMC PmcPeripheral;
AT91S_TC  Timer0Peripheral;
AT91S_PIO PioBPeripheral;

void setUp(void)
{
}

void tearDown(void)
{
}

void testEnablePeripheralClocksShouldEnableClockToTimer0Peripheral(void)
{
  AT91C_BASE_PMC->PMC_PCER = 0;
  Timer_EnablePeripheralClocks();
  TEST_ASSERT_EQUAL(
      TIMER0_CLOCK_ENABLE, 
      AT91C_BASE_PMC->PMC_PCER & TIMER0_CLOCK_ENABLE);
}

void testEnablePeripheralClocksShouldEnableClockToPIOBPeripheral(void)
{
  AT91C_BASE_PMC->PMC_PCER = 0;
  Timer_EnablePeripheralClocks();
  TEST_ASSERT_EQUAL(
      PIOB_CLOCK_ENABLE, 
      AT91C_BASE_PMC->PMC_PCER & PIOB_CLOCK_ENABLE);
}

void testResetShouldSetTimer0ClockDisableBit_DisableTimer0Interrupts_ClearStatusRegister(void)
{
  TIMER0_BASE->TC_CCR = 0;
  TIMER0_BASE->TC_IDR = 0;
  TIMER0_BASE->TC_SR = 0xFFFFFFFF;
  Timer_Reset();
  TEST_ASSERT_EQUAL(0x00000002, TIMER0_BASE->TC_CCR);
  TEST_ASSERT_EQUAL(0xffffffff, TIMER0_BASE->TC_IDR);
  // CANNOT BE VERIFIED!! TEST_ASSERT_EQUAL(0X00000000, TIMER0_BASE->TC_SR);
}

void testEnableOutputPinShouldEnable_TIOA0_DigitalOutput(void)
{
  PIOB_BASE->PIO_PDR = 0;
  Timer_EnableOutputPin();
  TEST_ASSERT_EQUAL(TIOA0_PIN_MASK, PIOB_BASE->PIO_PDR);
}

void testConfigureModeShouldConfigureTimer0ClockSourceForMasterClockDividedBy1024(void)
{
  TIMER0_BASE->TC_CMR = 0;
  Timer_ConfigureMode();
  TEST_ASSERT_EQUAL(0x00000004, TIMER0_BASE->TC_CMR & 0x00000007);
}

void testConfigureModeShouldConfigureTimer0ForWaveGeneration(void)
{
  TIMER0_BASE->TC_CMR = 0;
  Timer_ConfigureMode();
  TEST_ASSERT_EQUAL(0x00008000, TIMER0_BASE->TC_CMR & 0x00008000);
}

void testConfigureModeShouldConfigureTimer0ForUpModeWithAutomaticTriggerOnRCCompare(void)
{
  TIMER0_BASE->TC_CMR = 0;
  Timer_ConfigureMode();
  TEST_ASSERT_EQUAL(0x00004000, TIMER0_BASE->TC_CMR & 0x00006000);
}

void testConfigureModeShouldConfigureTimer0ToToggleTIOAOnRCCompare(void)
{
  TIMER0_BASE->TC_CMR = 0;
  Timer_ConfigureMode();
  TEST_ASSERT_EQUAL(0x000C0000, TIMER0_BASE->TC_CMR & 0x000C0000);
}

void testConfigurePeriodShouldConfigureRegisterCFor10msInterval(void)
{
  TIMER0_BASE->TC_RC = 0;
  Timer_ConfigurePeriod();
  TEST_ASSERT_EQUAL(469, TIMER0_BASE->TC_RC);
}

void testEnableShouldSetEnableFlagForTimer0(void)
{
  TIMER0_BASE->TC_CCR = 0;
  Timer_Enable();
  TEST_ASSERT_EQUAL_INT(1, TIMER0_BASE->TC_CCR);
}

void testConfigureInterruptHandler(void)
{
  Timer_DisableInterrupt_Expect();
  Timer_ResetSystemTime_Expect();
  Timer_ConfigureInterrupt_Expect();
  Timer_EnableInterrupt_Expect();

  Timer_ConfigureInterruptHandler();
}

void testStartShouldSetSoftwareTriggerFlag(void)
{
  TIMER0_BASE->TC_CCR = 0;
  Timer_Start();
  TEST_ASSERT_EQUAL(0x04, TIMER0_BASE->TC_CCR);
}
