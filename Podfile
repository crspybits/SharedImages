source 'https://github.com/CocoaPods/Specs.git'
source 'https://github.com/crspybits/Specs.git'

use_frameworks!

target 'SharedImages' do
	# Not using this because I made some mods to the ODRefreshControl code.
	# pod 'ODRefreshControl', '~> 1.2'

	pod 'Fabric'
	pod 'Crashlytics'

	pod 'SyncServer', '3.0.0'
	pod 'SyncServer/Facebook', '3.0.0'
	
# 	pod 'SyncServer', :path => '../SyncServer-iOSClient'
# 	pod 'SyncServer/Facebook', :path => '../SyncServer-iOSClient'
	
    pod 'GoogleSignIn', '4.0.2'
    
	target 'SharedImagesTests' do
    	inherit! :search_paths
    			
		pod 'SyncServer', '3.0.0'
		pod 'SyncServer/Facebook', '3.0.0'
		
# 		pod 'SyncServer', :path => '../SyncServer-iOSClient'
# 		pod 'SyncServer/Facebook', :path => '../SyncServer-iOSClient'

		pod 'GoogleSignIn', '4.0.2'
  	end
end

