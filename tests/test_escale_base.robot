*** Settings ***
Documentation     Energy scale base tests.


# Test Parameters:
# OPENBMC_HOST        The BMC host name or IP address.


Resource          ../lib/energy_scale_utils.robot
Resource          ../lib/openbmc_ffdc.robot


Suite Setup      Suite Setup Execution
Test Teardown    Test Teardown Execution



*** Variables ****

${over_max_power}       3051
${max_power}            3050
${mid_power}            1950
${min_power}            500
${below_min_power}      499
${zero_power}           0
#  The power limits shown above are documented at
#  open-power/witherspoon-xml/master/witherspoon.xml.


*** Test Cases ***


Escale Base Test Inactive Monitoring
    [Documentation]  Run base power tests with DCMI power montoring off.
    [Tags]  Escale_Base_Test_Deactive_Monitoring

    Deactivate DCMI Power And Verify
    Verify Power Limits


Escale Base Test Active Monitoring
    [Documentation]  Run base power tests with DCMI power monitoring on.
    [Tags]  Escale_Base_Test_Active_Monitoring

    Activate DCMI Power And Verify
    Verify Power Limits


Escale Power Setting Via REST And Verify
    [Documentation]  Set power via REST and check using IPMI.
    [Tags]  Escale_Power_Setting_Via_REST_And_Verify

    # A convenient power level bewtwwn maximum and minimum.
    ${test_power}=  Set Variable  1700

    # Set the power limit via REST.
    Set DCMI Power Limit Via REST  ${test_power}

    # Read the power limit using IPMI.
    ${power_limit}=  Get DCMI Power Limit
    Should Be True  ${power_limit} == ${test_power}
    ...  msg=Reading Power limit with IPMI failed after setting it with REST.


Escale Power Setting Via IPMI And Verify
    [Documentation]  Set power via IPMI then check via REST.
    [Tags]  Escale_Power_Setting_Via_IPMI_And_Verify

    # A convenient power level bewtwwn maximum and minimum.
    ${test_power}=  Set Variable  2200

    # Set DCMI Power via IPMI.
    Set DCMI Power Limit And Verify  ${test_power}

    # Read the limit via REST.
    ${power_limit}=  Get DCMI Power Limit Via REST
    Should Be True  ${power_limit} == ${test_power}
    ...  msg=Reading power limit with REST failed after setting it with IPMI.


Escale Activation Test Via REST
    [Documentation]  Activate power monitoring via REST then check via IPMI.
    [Tags]  Escale_Activation_Test_Via_REST

    Activate DCMI Power Via REST
    # Confirm activation state using IPMI.
    Fail If DCMI Power Is Not Activated


Escale Dectivation Test Via REST
    [Documentation]  Deactivate power monitoring via REST and check via IPMI.
    [Tags]  Escale_Deactivation_Test_Via_REST

    Deactivate DCMI Power Via REST
    # Confirm activation state using IPMI.
    Fail If DCMI Power Is Not Deactivated


*** Keywords ***


Verify Power Limits
    [Documentation]  Set power levels and verify limits.

    Set DCMI Power Limit And Verify  ${mid_power}
    Test Power Limit  ${min_power}  ${below_min_power}
    Test Power Limit  ${min_power}  ${zero_power}
    Test Power Limit  ${max_power}  ${over_max_power}


Test Power Limit
    [Documentation]  Set power and check limit.
    [Arguments]  ${good_power}  ${outside_bounds_power}

    # Description of argument(s):
    # good_power              A valid power setting, usually at a limit.
    # outside_bounds_power    A power level that is beyond the limit.

    Set DCMI Power Limit And Verify  ${good_power}

    # Try to set out of bounds.
    ${expected_error}=  Set Variable
    ...  Failed setting dcmi power limit to ${outside_bounds_power} watts.
    Run Keyword and Expect Error  ${expected_error}
    ...  Set DCMI Power Limit And Verify  ${outside_bounds_power}


Suite Setup Execution
    [Documentation]  Do test setup initialization.

    # Save the deactivation/activation setting.
    ${cmd}=  Catenate  dcmi power get_limit | grep State
    ${resp}=  Run External IPMI Standard Command  ${cmd}
    # Response is either "Power Limit Active" or "No Active Power Limit".
    ${initial_deactivation}=  Get Count  ${resp}  No
    # If deactivated: initial_deactivation = 1, 0 otherwise.
    Set Suite Variable  ${initial_deactivation}  children=true

    # Save the power limit setting.
    ${initial_power_setting}=  Get DCMI Power Limit
    Set Suite Variable  ${initial_power_setting}  children=true


Test Teardown Execution
    [Documentation]  Do the post test teardown.

    FFDC On Test Case Fail

    # Restore the system's intial power limit setting.
    Run Keyword If  '${initial_power_setting}' != '${0}'
    ...  Set DCMI Power Limit And Verify  ${initial_power_setting}

    # Restore the system's intial deactivation/activation setting.
    Run Keyword If  '${initial_deactivation}' == '${1}'
    ...  Deactivate DCMI Power And Verify  ELSE  Activate DCMI Power And Verify