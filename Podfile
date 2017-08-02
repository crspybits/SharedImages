source 'https://github.com/CocoaPods/Specs.git'
source 'https://github.com/crspybits/Specs.git'

use_frameworks!

target 'SharedImages' do
	# Not using this because I made some mods to the ODRefreshControl code.
	# pod 'ODRefreshControl', '~> 1.2'
	
	pod 'SevenSwitch', '~> 2.1'
	
	pod 'SyncServer'
	pod 'SyncServer/Facebook'
	
    pod 'GoogleSignIn', '4.0.2'
    
	target 'SharedImagesTests' do
    	inherit! :search_paths
    	
		pod 'SevenSwitch', '~> 2.1'
		
		pod 'SyncServer'
		pod 'SyncServer/Facebook'

		pod 'GoogleSignIn', '4.0.2'
  	end
end

