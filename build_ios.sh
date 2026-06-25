
cd aip_app && flutter clean && flutter pub get && flutter build ios --release && ios-deploy --bundle build/ios/iphoneos/Runner.app --id <设备uuid> 
