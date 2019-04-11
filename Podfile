source 'https://github.com/crspybits/Specs.git'
source 'https://github.com/CocoaPods/Specs.git'

use_frameworks!
platform :ios, '10.0'

target 'SharedImages' do
	# https://stackoverflow.com/questions/13208202
	# ignore all warnings from all pods
	inhibit_all_warnings!

	pod 'Fabric'
	pod 'Crashlytics'

	pod 'SyncServer', '~> 19.2.1'
	pod 'SyncServer/Facebook', '~> 19.2.1'
	pod 'SyncServer/Dropbox', '~> 19.2.1'
	pod 'SyncServer/Google', '~> 19.2.1'

# 	pod 'SyncServer', :path => '../SyncServer-iOSClient'
# 	pod 'SyncServer/Facebook', :path => '../SyncServer-iOSClient'
# 	pod 'SyncServer/Dropbox', :path => '../SyncServer-iOSClient'
# 	pod 'SyncServer/Google', :path => '../SyncServer-iOSClient'

# 	pod 'SyncServer-Shared', :path => '../SyncServer-Shared'
	
# 	pod 'SMCoreLib', :path => '../Common/SMCoreLib/'
	pod 'SMCoreLib', '~> 2.0'
	
	# For a discussion thread on images
	pod 'MessageKit', '~> 2.0'

	# Using my fork because of changes I made
	pod 'ODRefreshControl', :git => 'https://github.com/crspybits/ODRefreshControl.git'
    
    pod 'SDCAlertView', '~> 9.0'
    
    # pull-up from the bottom to refresh
    pod 'LottiesBottom', '~> 0.5'
	# pod 'LottiesBottom', :path => '../LottiesBottom/'
	# pod 'LottiesBottom', :git => 'https://github.com/crspybits/LottiesBottom.git'

    # developer dashboard
    # pod 'rosterdev', :git => 'https://github.com/RosterHQ/rosterdev.git'
    pod 'rosterdev', '~> 0.1'
    
    # for badges for updates to discussion threads
    pod 'BadgeSwift', '~> 6.0'
    
    # Improved presentation of smaller modals
    pod 'Presentr', '~> 1.3'
    
    # For sorting/filter modal.
    pod 'DropDown', '~> 2.3'
	# pod 'DropDown', :path => '../DropDown'
	# pod 'DropDown', :git => 'https://github.com/crspybits/DropDown.git'

	pod 'NohanaImagePicker', :git => 'https://github.com/crspybits/NohanaImagePicker.git'
	# pod 'NohanaImagePicker', :path => '../NohanaImagePicker'
	
	pod 'XCGLogger', '~> 6.1'
	
	# Main menu navigation.
	pod 'LGSideMenuController', '~> 2.1'
	
	pod 'NVActivityIndicatorView', '~> 4.7'
	
	# Navigation directions using Google Maps, Apple Maps etc.
	pod 'Karte', '~> 2.2'
	
	# Geocoding
	pod 'SwiftLocation', '~> 3.2'
    
	target 'SharedImagesTests' do
    	inherit! :search_paths
  	end
end

