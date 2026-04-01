# App Store Images

Place screenshots and icons here for F-Droid listing.

## Expected structure

```
images/
├── icon.png                    # App icon (512x512 PNG)
├── featureGraphic.png          # Feature graphic (1024x500 PNG)
├── phoneScreenshots/
│   ├── 1.png                   # Screenshot 1
│   ├── 2.png                   # Screenshot 2
│   └── ...
└── sevenInchScreenshots/       # Optional: 7-inch tablet screenshots
    └── ...
```

## Guidelines

- **icon.png**: 512x512 pixels, PNG format
- **featureGraphic.png**: 1024x500 pixels, PNG format (displayed at top of F-Droid listing)
- **phoneScreenshots/**: Phone screenshots, recommended 1080x1920 or similar portrait ratio
- Screenshots should showcase key features: create shards, scan QR codes, restore secret, files management
- F-Droid will pick up these images automatically during the build process
- Other locales (ru, uk, be, tr, ka, pl) inherit from en-US unless they have their own images/ directory
