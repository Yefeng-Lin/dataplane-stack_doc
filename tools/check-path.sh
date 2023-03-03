
check_vpp()
{
    if ! [[ $(command -v ${vpp_binary}) ]]; then
          echo "User specified VPP binary path are missing/invalid: ${vpp_binary}"
          echo "Attempting to auto-detect proper path..."
          export vpp_binary=$(command -v "${DATAPLANE_TOP}/components/vpp/build-root/install-vpp-native/vpp/bin/vpp")
          vpp_binary=${vpp_binary:-vpp}         
    fi                                        
                                          
    if ! [ $(command -v ${vpp_binary}) ]; then  
          echo                                  
          echo "Can't find vpp at: ${vpp_binary}"               
          exit 1                                
    fi                                        
                                          
    echo "Found VPP binary at: $(command -v ${vpp_binary})"
}

check_vppctl()
{
    if ! [[ $(command -v ${vppctl_binary}) ]]; then
          echo "User specified VPPCTL binary path are missing/invalid: ${vppctl_binary}"
          echo "Attempting to auto-detect proper path..."
          export vppctl_binary=$(command -v "${DATAPLANE_TOP}/components/vpp/build-root/install-vpp-native/vpp/bin/vppctl")
          vppctl_binary=${vppctl_binary:-vppctl}
    fi                                        
 
    if ! [ $(command -v ${vppctl_binary}) ]; then
          echo                                  
          echo "Can't find vppctl at: ${vppctl_binary}"            
          exit 1                                
    fi                                        
                                          
    echo "Found VPPCTL binary at: $(command -v ${vppctl_binary})"
}

check_ldp()
{
    if ! [[ $(command -v ${LDP_PATH}) ]]; then
          echo "User specified libvcl_ldpreload.so path are missing/invalid: ${LDP_PATH}"
          echo "Attempting to auto-detect proper path..."
          export LDP_PATH=$(command -v "${DATAPLANE_TOP}/components/vpp/build-root/install-vpp-native/vpp/lib/aarch64-linux-gnu/libvcl_ldpreload.so")
          LDP_PATH=${LDP_PATH:-"/usr/lib/libvcl_ldpreload.so"}
    fi                                        
 
    if ! [ $(command -v ${LDP_PATH}) ]; then
          echo                                  
          echo "Can't find libvcl_ldpreload.so at: ${LDP_PATH}"            
          exit 1                                
    fi                                        
                                          
    echo "Found libvcl_ldpreload.so at: $(command -v ${LDP_PATH})"
}
