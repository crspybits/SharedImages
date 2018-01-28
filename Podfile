source 'https://github.com/CocoaPods/Specs.git'
source 'https://github.com/crspybits/Specs.git'

use_frameworks!

target 'SharedImages' do
	pod 'Fabric'
	pod 'Crashlytics'

	pod 'SyncServer', '~> 11.0'
	pod 'SyncServer/Facebook', '~> 11.0'
	pod 'SyncServer/Dropbox', '~> 11.0'
	
# 	pod 'SyncServer', :path => '../SyncServer-iOSClient'
# 	pod 'SyncServer/Facebook', :path => '../SyncServer-iOSClient'
# 	pod 'SyncServer/Dropbox', :path => '../SyncServer-iOSClient'
# 	pod 'SyncServer-Shared', :path => '../SyncServer-Shared'
	
# 	pod 'SMCoreLib', :path => '../Common/SMCoreLib/'

	# Using my fork because of changes I made
	pod 'ODRefreshControl', :git => 'https://github.com/crspybits/ODRefreshControl.git'
	
    pod 'GoogleSignIn', '~> 4.1'
    
    pod 'SDCAlertView', '~> 7.1'
    
    # pull-up from the bottom to refresh
    pod 'LottiesBottom', '~> 0.4'
    # pod 'LottiesBottom', :path => '../LottiesBottom/'
    
    # developer dashbaord
    pod 'rosterdev', :git => 'https://github.com/RosterHQ/rosterdev.git'
    
    # for badges for updates to discussion threads
    pod 'BadgeSwift', '~> 5.0'
    
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

