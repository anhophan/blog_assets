# fido_tpm_attestation_fix.ps1

#
# This script automates the detection and remediation steps documented
# in support case: https://serviceshub.microsoft.com/support/case/2408230030005147
#
# The short version of this support case is that users cannot register Windows Hello
# against IBM FIDO servers because the TPM attestation is built by the Microsoft Windows
# client using a revoked AIK certificate and the certificate renewal process has not
# run automatically. Whilst we don't know the underlying reason for ending up in that 
# state, this script attempts to recover from the broken state by manually removing the
# revoked AIK certificate and re-running the tasks to provision a new one.
#
# The list of revoked serial numbers below may change over time. This list can be generated
# on a separate Mac or Linux machine that has the OpenSSL command line utility with the following
# command:
#
# curl "http://www.microsoft.com/pkiops/crl/Microsoft%20TPM%20Root%20Certificate%20Authority%202014.crl" 2>/dev/null | openssl crl -text | grep "Serial Number" | sed -e "s/.*Serial Number: \(.*\)$/\"\1\"/" | sed -e "$ ! s/\(.*\)$/\1,/"
#
# The sed scripts at the end clean up the serial numbers, add quotes, and (for all but the last line) add a trailing comma.
#
#
# If you encounter an error indicating that running scripts is disabled on your system, run PowerShell as Administrator then:
#
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
#
# Select Y to allow. Then the script should execute ok. You can use this command to see current execution policy:
#
# Get-ExecutionPolicy -List
#

$revokedSerialNumbers=@(
"33000003338EBD5049299D04AD000000000333",
"3300000328E90EC46106331B77000000000328",
"330000031D9F94BB3B034E1C5700000000031D",
"33000006471D88BA2E431D289D000000000647",
"330000063A86A8299B0679140400000000063A",
"330000062DAEC86B08B99C2B3300000000062D",
"330000032EF288D662C71FDADD00000000032E",
"3300000323EF67FAE5067F668E000000000323",
"3300000318ECB22506D6A2A0BA000000000318",
"3300000641DB1A4C938A6BDD1B000000000641",
"3300000634B974A3CB9C06FE45000000000634",
"33000006276335B45AA23B9E94000000000627",
"330000032D0A26F66B7AAA75E700000000032D",
"3300000322030CA4B6D3CB7B06000000000322",
"3300000317A8C56C8089536DD8000000000317",
"330000064038FBD64DEBDF6D06000000000640",
"3300000633843B6358CC8C5BEC000000000633",
"3300000626C8723516CFF4A227000000000626",
"330000032C65CBEB4905EFF9C200000000032C",
"330000032104437AF8708C4E82000000000321",
"3300000316495FB6018CC27548000000000316",
"330000063F8EA7E1D7747DD8EC00000000063F",
"3300000632468ED0EC48FA9E30000000000632",
"3300000625D4C96D2A668DC3B5000000000625",
"3300000332D3B316D8ABC230FA000000000332",
"3300000327B747D4C96B7C7E35000000000327",
"330000031C4EA3CF0DE40304D800000000031C",
"3300000645E1FB9030759A4B4A000000000645",
"33000006386168E40D1B74FC88000000000638",
"330000062BF37BFF3B8921FA7100000000062B",
"3300000336ABB091B9772C27D7000000000336",
"330000032B1EF58FF9337629F800000000032B",
"3300000320603FCD992A9BF0DF000000000320",
"330000064AC0BBBCA0D05EAFBA00000000064A",
"330000063DB3CC1E9D848408A000000000063D",
"33000006302F5C723CD07BC8F4000000000630",
"330000033195B6236A7FE06DD8000000000331",
"330000032615A755692B2C3210000000000326",
"330000031B42EBBF03A98172CA00000000031B",
"33000006441CE1637316B537C2000000000644",
"3300000637E782350303EADAEC000000000637",
"330000062A0C6A82BA99BE42D300000000062A",
"33000003304BAA446ADD8B56C2000000000330",
"3300000325CBA359E8C7F9BC0D000000000325",
"330000031AB905F0C44E26B96600000000031A",
"33000006430244FAFA19039871000000000643",
"3300000636B1C8B4150529261A000000000636",
"33000006291159A24FFF74E9DD000000000629",
"3300000335C6069B8950A7C3E7000000000335",
"330000032ACD0AD6E8BF8CD0A700000000032A",
"330000031F36C6FA40E60778A900000000031F",
"33000006494B8259C4A453E09F000000000649",
"330000063C086B6125369F17C000000000063C",
"330000062F45296885B839723B00000000062F",
"330000039954D89CFBCE6F8F43000000000399",
"33000003941C66CA26DD2C714E000000000394",
"330000038F61E31D09E31FFBD800000000038F",
"330000033448D3A569FFA479BB000000000334",
"330000032999AD041768113B3C000000000329",
"330000031EB235367BBBECB00F00000000031E",
"330000064829B4DFF68A1AF1D6000000000648",
"330000063B7426874BC7E3442C00000000063B",
"330000062E4613926CC3C1043700000000062E",
"330000076C8E7640EB647B97B200000000076C",
"330000076BAB2A4D4B9B09D6C100000000076B",
"330000076AA4D7C5C8E3C6BDE600000000076A",
"33000008F1C5425385ABC291150000000008F1",
"33000009153769CBD3F4F71BC9000000000915",
"3300000910D2A457AFEA629D4D000000000910",
"330000089FF0C1B2218B5744F700000000089F",
"330000089E389D0E91DC243C2500000000089E",
"330000089DBCED733519A1F15B00000000089D",
"330000089C334506AB7E3C4F9E00000000089C",
"330000089BD768422A37A1D95100000000089B",
"330000089A2940150D987B859400000000089A",
"33000008991B72269F94BD292D000000000899",
"3300000898F9475396F8EC9B79000000000898",
"3300000897C9198448FE2CCB89000000000897",
"3300000896F157BAE927D9F472000000000896",
"3300000895F1385061DFCAFF3E000000000895",
"330000089428B50A5EC3EC9026000000000894",
"33000008932FE74B1D8837F49D000000000893",
"330000089207ADA9EBD2D5C9F7000000000892",
"33000008912EAEA4381056E0C6000000000891",
"3300000890762D004D2B70C306000000000890",
"330000088F9EB4F43B7711629100000000088F",
"330000088E78947B89F9DDFAAE00000000088E",
"330000088D48295F7B7A568A0600000000088D",
"330000088CBA2E395EC7C86A9000000000088C",
"330000088B825B66058AEA56FE00000000088B",
"330000088AE3DC4A0615C3476200000000088A",
"3300000889C0B2F8A1E42B8B06000000000889",
"330000088802608D08AC493DE6000000000888",
"330000088796340B614FC7599E000000000887",
"3300000886F26431865E5C3831000000000886",
"330000088547808AA2D58AB186000000000885",
"33000008846CDCE5EE8C1648E0000000000884",
"3300000883434E4C62B7AB2843000000000883",
"3300000882714CBA05E9C4DEC2000000000882",
"33000008517D3D13F2111F4018000000000851",
"33000008507410EC17E93491D5000000000850",
"330000084FDFE51F456BAF231E00000000084F",
"3300000857E5DF79EA7FCCE441000000000857",
"330000085698654D7CB5F3C03E000000000856",
"3300000855AC633611A689D8C5000000000855",
"330000085442D14AA129BBA94C000000000854",
"3300000853C25147B6D390F5B9000000000853",
"3300000852241888CF7BD3B463000000000852",
"3300000840590938F4B12E93FB000000000840",
"330000084ACD96546AD3E970B500000000084A",
"330000084862BB6FBF0921BEA7000000000848",
"330000084EDFF7583C5E9E1CFF00000000084E",
"330000083F41B8271D9CC90DF700000000083F",
"3300000835BBCC5C2FD9B03A9F000000000835",
"330000083244F0041C953B7EDC000000000832",
"330000084CECB8468A2F053E5700000000084C",
"330000083878290DCA44D028B4000000000838",
"3300000830E5D9E13E6FBDF056000000000830",
"330000082E436DE5463C74B3A900000000082E",
"330000084D95884AD7F85086CA00000000084D",
"330000015A0611E3228FCB5DD800000000015A",
"330000015244C886FA4F1C5C31000000000152",
"3300000140E3D84DD9DB9FB397000000000140",
"330000013EC0D51298212D639D00000000013E",
"33000001485915D1DEA87B7852000000000148",
"330000012A36D477018B106E8B00000000012A",
"330000011E682725482A6B69B600000000011E",
"33000000F6197616F4C3AA82900000000000F6",
"33000000CCF3EA553CDEF082FA0000000000CC",
"33000000EBB0FCF1A0FCE4CD3A0000000000EB",
"33000000BF80CBD02537A16B760000000000BF",
"33000000DE6AE1765C7F548BD30000000000DE",
"330000006346729B9ADD6D0985000000000063",
"330000005D15AD7A2A5726FA3600000000005D",
"33000000257B77B8AC957823A7000000000025",
"3300000023D6E8AC85BC63DCD3000000000023",
"33000001581227AD87539BB92F000000000158",
"33000000FA69625C09208275040000000000FA",
"3300000164941AFE0C7037C4AA000000000164",
"330000005FAA9C1CF40691026000000000005F",
"3300000156E6A9EA47F3186BA6000000000156",
"33000001638C30E3ED1E841C2E000000000163",
"33000000AF9B52D280611F6BF20000000000AF",
"33000000B27F5F4C8E77672D700000000000B2",
"3300000144AAF06AA8AFF7831E000000000144",
"33000000A0F183517EFB429AB50000000000A0",
"3300000136225A6C5FA90A22A9000000000136",
"3300000024A89D3C39F3D1D921000000000024",
"3300000143377292EA39AAEFA6000000000143",
"3300000142D23709D56BB6CA8B000000000142",
"3300000155C74CC564BEB7F1AF000000000155",
"33000000648E11630F7E543BA0000000000064",
"33000000F8D6C5324398FAB4FC0000000000F8",
"330000015FB3C34A65A9CF80E500000000015F",
"330000005E7974490163A88F4300000000005E",
"33000001536D82F329F5E4E799000000000153",
"33000000ED3D2B072D990DC4960000000000ED",
"3300000146902EA98DA5BB3010000000000146",
"33000000ADBDDBB8FCFE41D1F20000000000AD",
"33000001474DB62517EF7AA23E000000000147",
"330000015E34399D0C39E51D2900000000015E",
"33000000F05C69922C5F3BFB4A0000000000F0",
"330000006533FDF0A34F12E2BD000000000065",
"330000013FE4AAA9B392A78B1700000000013F",
"330000015035F8823F8C72605A000000000150",
"3300000159D2EB342B2FE26F1D000000000159",
"33000000CE05DF2662AE27B0AF0000000000CE",
"33000000D1733CC51D4E382A270000000000D1"
)


$props=@("SerialNumber" ,"Issuer")

$foundRevokedCertificate = $false

# First phase is detection and removal of any known revoked certificates
# If any found, set the foundRevokedCertificate flag to true so that the 
# remediation phase is performed
Get-ChildItem -Path 'Cert:\LocalMachine\CA' |
    ForEach-Object {
        $cert = $_
        $sn = $cert.SerialNumber
        if ($revokedSerialNumbers -contains $sn) {
            $foundRevokedCertificate = $true
            $sub = $cert.Subject
            Write-Host "Removing revoked certificate `: $sub"
            ForEach ($p in $props) {
                $val = $cert.$p
                Write-Host "    $p`: $val"
            }    

            # Delete the revoked certificate
            $cert | Remove-Item
        }        
    }

# Perform remediation if needed
if ($foundRevokedCertificate) {
    Write-Host "One or more revoked certificates detected and removed - performing remediation..."

    $regkeys=@(
        "HKLM:SYSTEM\CurrentControlSet\Control\Cryptography\Ngc\AIK",
        "HKLM:SYSTEM\CurrentControlSet\Control\Cryptography\Ngc\AIKCertEnroll",
        "HKLM:SYSTEM\CurrentControlSet\Control\Cryptography\Ngc\PregenKeys"
    )

    ForEach ($k in $regkeys) {
        if (Test-Path $k) {
            Write-Host "Deleting `: $k"
            Remove-Item -Path $k -Recurse -Force
        } else {
            Write-Host "Skipping registry key that did not exist`: $k"
        }
    }

    # Run the KeyPreGenTask followed by the AikCertEnrollTask
    # Each is given up to 60 seconds to complete
    $taskPath = "\Microsoft\Windows\CertificateServicesClient\"
    $taskNames = @("KeyPreGenTask", "AikCertEnrollTask")
    $taskError = $false
    ForEach ($taskName in $taskNames) {
        if (-Not $taskError) {
            Write-Host "Starting $taskName"
            Start-ScheduledTask -TaskPath $taskPath -TaskName $taskName

            $timeout = 60
            $timer = [Diagnostics.Stopwatch]::StartNew()
            while (((Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName).State -ne 'Ready') -and ($timer.Elapsed.TotalSeconds -lt $timeout)) {
                Write-Host "Waiting for task $taskName to finish..."
                Start-Sleep -Seconds 2
            }
            $timer.Stop()
            if ($timer.Elapsed.TotalSeconds -ge $timeout) {
                $taskError = $true
                Write-Host "Task $taskName timed out - aborting."
            } else {
                Write-Host "Task $taskName completed in $($timer.Elapsed.TotalSeconds) seconds"
            }
        }
    }

    if (-Not $taskError) {
        Write-Host "AIK certificate enrollment complete. Please try registering Windows Hello again."
    }

} else {
    Write-Host "No revoked AIK certificates detected, doing nothing"
}
