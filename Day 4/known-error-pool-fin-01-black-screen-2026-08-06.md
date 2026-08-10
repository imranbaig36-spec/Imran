Symptom     : Users on POOL-FIN-01 saw a black screen after logon. For some users the desktop appeared after about 30 seconds; others required manual reconnection.

Cause       : The verified root cause was a defective Intel GPU driver, igdumd64.dll v31.0.101.4146, introduced by the 02:00 AM overnight POOL-FIN-01 image update. The driver crashed during desktop composition initialization and caused dwm.exe failures.

Scope       : Impact was limited to AVD POOL-FIN-01 and affected about 40% of roughly 200 users (about 80 users). POOL-FIN-02 remained unaffected with 0% impact.

Workaround  : Restore service by rolling back POOL-FIN-01 to the pre-update image build-20240313 with Intel driver v31.0.101.4046, then reboot session hosts. During recovery, set hosts to drain mode (AllowNewSession:$false) so existing sessions can complete while rollback runs.

Permanent fix: Keep POOL-FIN-01 on the stable build/driver baseline (build-20240313, igdumd64.dll v31.0.101.4046) and block deployment of the defective driver version 31.0.101.4146. Enforce a pre-deployment driver validation gate and maintain a known-defective-driver blocklist in the image pipeline.

How to spot it: Look for Event ID 1000 (Application Error) showing faulting application dwm.exe and faulting module igdumd64.dll v31.0.101.4146 with exception code 0xc0000005 and fault offset 0x0000000000047f12. Correlated signals include Event ID 9009 (Desktop Window Manager exited with code 0x40010004), Event ID 40 session disconnects, and repeated Event ID 21 logon/reconnect attempts.