source 'https://github.com/CocoaPods/Specs.git'
source 'https://github.com/crspybits/Specs.git'

use_frameworks!

target 'SharedImages' do
	# Not using this because I made some mods to the ODRefreshControl code.
	# pod 'ODRefreshControl', '~> 1.2'
	
	pod 'SevenSwitch', '~> 2.1'
	pod 'SyncServer', :path => '../Client/'
	
	# These two should only be needed right now because I've not pushed the SyncServer pod up to a repo yet.
	pod 'SMCoreLib'
	pod 'SyncServer-Shared'
	
    pod 'Google/SignIn'
    
	target 'SharedImagesTests' do
    	inherit! :search_paths
    	
		pod 'SevenSwitch', '~> 2.1'
		pod 'SyncServer', :path => '../Client/'
		pod 'SMCoreLib'
		pod 'Google/SignIn'
  	end
end

