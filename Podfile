source 'https://github.com/CocoaPods/Specs.git'
source 'https://github.com/crspybits/Specs.git'

use_frameworks!

target 'SharedImages' do
	pod 'Fabric'
	pod 'Crashlytics'

	pod 'SyncServer', '3.1.1'
	pod 'SyncServer/Facebook', '3.1.1'
	
# 	pod 'SyncServer', :path => '../SyncServer-iOSClient'
# 	pod 'SyncServer/Facebook', :path => '../SyncServer-iOSClient'

	# Using my fork because of changes I made
	pod 'ODRefreshControl', :git => 'https://github.com/crspybits/ODRefreshControl.git'
	
    pod 'GoogleSignIn', '4.0.2'
    
	target 'SharedImagesTests' do
    	inherit! :search_paths
    			
		pod 'SyncServer', '3.1.1'
		pod 'SyncServer/Facebook', '3.1.1'
		
# 		pod 'SyncServer', :path => '../SyncServer-iOSClient'
# 		pod 'SyncServer/Facebook', :path => '../SyncServer-iOSClient'

		pod 'GoogleSignIn', '4.0.2'
  	end
end

