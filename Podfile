source 'https://github.com/CocoaPods/Specs.git'
source 'https://github.com/crspybits/Specs.git'

use_frameworks!

target 'SharedImages' do
	pod 'Fabric'
	pod 'Crashlytics'

	pod 'SyncServer', '~> 15.1'
	pod 'SyncServer/Facebook', '~> 15.1'
	pod 'SyncServer/Dropbox', '~> 15.1'
	
# 	pod 'SyncServer', :path => '../SyncServer-iOSClient'
# 	pod 'SyncServer/Facebook', :path => '../SyncServer-iOSClient'
# 	pod 'SyncServer/Dropbox', :path => '../SyncServer-iOSClient'
	
# 	pod 'SyncServer-Shared', :path => '../SyncServer-Shared'
	
# 	pod 'SMCoreLib', :path => '../Common/SMCoreLib/'

	pod 'SMCoreLib', '~> 1.3.1'
	
	# For a discussion thread on images
	pod 'MessageKit', '~> 0.13'

	# Using my fork because of changes I made
	pod 'ODRefreshControl', :git => 'https://github.com/crspybits/ODRefreshControl.git'
	
    pod 'GoogleSignIn', '~> 4.1'
    
    pod 'SDCAlertView', '~> 7.1'
    
    # pull-up from the bottom to refresh
    pod 'LottiesBottom', '~> 0.4'
    # pod 'LottiesBottom', :path => '../LottiesBottom/'
    
    # developer dashboard
    # pod 'rosterdev', :git => 'https://github.com/RosterHQ/rosterdev.git'
    pod 'rosterdev', '~> 0.1'
    
    # for badges for updates to discussion threads
    pod 'BadgeSwift', '~> 5.0'
    
    # Improved presentation of smaller modals
    pod 'Presentr', '~> 1.3'
    
    # For sorting/filter modal.
    pod 'DropDown', '~> 2.3'
    
	target 'SharedImagesTests' do
    	inherit! :search_paths
  	end
  	
  	# 9/14/17; Cocoapods isn't quite ready for Xcode9. This is a workaround:
	# See also https://github.com/CocoaPods/CocoaPods/issues/6791
	
	post_install do |installer|
	
		myTargets = ['Gloss', 'SDCAlertView', 'SyncServer-Shared', 'FacebookCore', 'SyncServer', 'SMCoreLib']
		
		installer.pods_project.targets.each do |target|
			if myTargets.include? target.name
				target.build_configurations.each do |config|
					config.build_settings['SWIFT_VERSION'] = '3.2'
				end
			end
		end
	end
end

