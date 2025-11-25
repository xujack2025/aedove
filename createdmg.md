# Creating DMG for macOS Distribution

## Step 1: Prepare Your App Folder

Open **Terminal** and run these commands:

```bash
# Create a temporary folder for DMG contents
mkdir ~/Desktop/MyAppDMG

# Copy your app to this folder
cp -R /Users/User/Documents/MyApp/MyApp.app ~/Desktop/MyAppDMG/

# Create a shortcut to Applications folder (allows drag-and-drop install)
ln -s /Applications ~/Desktop/MyAppDMG/Applications
```

**What you should see:**
- A new folder called `MyAppDMG` appears on your Desktop
- Inside it: `MyApp.app` and an `Applications` shortcut

---

## Step 2: Create DMG File

### Option A: Using Disk Utility (GUI Method)

1. Open **Disk Utility** app (in `/Applications/Utilities/`)
2. Click **File** → **New Image** → **Image from Folder...**
3. Navigate to and select the `MyAppDMG` folder on your Desktop
4. Click **Open**
5. In the save dialog:
   - **Save As:** `MyApp-1.0.0`
   - **Where:** Desktop (or choose your location)
   - **Image Format:** Select **compressed**
   - **Encryption:** None
6. Click **Save**
7. Wait for compression to complete

**Result:** `MyApp-1.0.0.dmg` file created

---

### Option B: Using Terminal (Command Line Method)

```bash
# Create compressed DMG from folder
hdiutil create -volname "MyApp" -srcfolder ~/Desktop/MyAppDMG -ov -format UDZO ~/Desktop/MyApp-1.0.0.dmg
```

**Command breakdown:**
- `hdiutil create` = macOS disk image utility
- `-volname "MyApp"` = Name shown when DMG is mounted
- `-srcfolder ~/Desktop/MyAppDMG` = Source folder to convert
- `-ov` = Overwrite if file exists
- `-format UDZO` = Compressed format (smallest size)
- `~/Desktop/MyApp-1.0.0.dmg` = Output file location

**What you should see:**
```
Preparing imaging engine…
Reading MyAppDMG
....................................................................
Adding resources...
Elapsed Time: 5.234s
File size: 45.2 MB
created: /Users/User/Desktop/MyApp-1.0.0.dmg
```

---

## Step 3: Test Your DMG

```bash
# Open the DMG to test it
open ~/Desktop/MyApp-1.0.0.dmg
```

**What you should see:**
- DMG mounts and opens a Finder window
- Shows `MyApp.app` and `Applications` shortcut
- You can drag the app to Applications to "install"

```bash
# Unmount when done testing
hdiutil detach /Volumes/MyApp
```

---

## Step 4: Upload to cPanel

### Using cPanel File Manager:

1. **Login to cPanel** at `https://yourdomain.com/cpanel`
2. Click **File Manager** icon
3. Navigate to **public_html** folder
4. Click **+ Folder** button
   - Folder name: `downloads`
   - Click **Create New Folder**
5. Double-click to open the `downloads` folder
6. Click **Upload** button at the top
7. Click **Select File** button
8. Navigate to Desktop and select `MyApp-1.0.0.dmg`
9. Wait for upload progress bar to complete (shows green checkmark)
10. Close upload dialog

### Using Terminal (if you have SSH access):

```bash
# Upload via SCP (replace with your details)
scp ~/Desktop/MyApp-1.0.0.dmg username@yourdomain.com:public_html/downloads/

# Enter your cPanel password when prompted
```

---

## Step 5: Set File Permissions

### In cPanel File Manager:

1. Navigate to `public_html/downloads/`
2. Right-click on `MyApp-1.0.0.dmg`
3. Click **Change Permissions**
4. Set to: **644** (Read for everyone, write for owner)
   - ✅ Owner: Read, Write
   - ✅ Group: Read
   - ✅ World: Read
5. Click **Change Permissions**

### Using Terminal (if you have SSH):

```bash
ssh username@yourdomain.com
cd public_html/downloads
chmod 644 MyApp-1.0.0.dmg
exit
```

---

## Step 6: Add Download Link to Website

Create or edit your HTML file:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Download MyApp</title>
</head>
<body>
    <h1>Download MyApp for macOS</h1>
    
    <a href="https://yourdomain.com/downloads/MyApp-1.0.0.dmg" download>
        <button>Download MyApp 1.0.0 (45 MB)</button>
    </a>
    
    <p>Requirements: macOS 10.15 or later</p>
    
    <h3>Installation:</h3>
    <ol>
        <li>Download the DMG file</li>
        <li>Open the downloaded file</li>
        <li>Drag MyApp.app to the Applications folder</li>
        <li>Launch from Applications</li>
    </ol>
</body>
</html>
```

---

## Step 7: Test Download

```bash
# Test download from terminal
curl -O https://yourdomain.com/downloads/MyApp-1.0.0.dmg

# Or open in browser
open https://yourdomain.com/downloads/MyApp-1.0.0.dmg
```

**What should happen:**
- File downloads without errors
- DMG opens correctly
- App can be installed by dragging to Applications

---

## Step 8: Cleanup (Optional)

```bash
# Remove temporary folder
rm -rf ~/Desktop/MyAppDMG

# Keep the DMG file for backup/future uploads
```

---

## Verification Checklist

- [ ] DMG file created successfully
- [ ] DMG opens and shows app + Applications shortcut
- [ ] File uploaded to cPanel
- [ ] Permissions set to 644
- [ ] Download link works in browser
- [ ] File downloads completely
- [ ] Downloaded DMG opens correctly
- [ ] App can be dragged to Applications

---

## File Size Optimization (Optional)

If your DMG is too large:

```bash
# Check current size
ls -lh ~/Desktop/MyApp-1.0.0.dmg

# Create more compressed version
hdiutil create -volname "MyApp" -srcfolder ~/Desktop/MyAppDMG -ov -format UDBZ ~/Desktop/MyApp-1.0.0.dmg

# UDBZ = even more compressed (but slower to create)
```

---

## Troubleshooting

### "Permission denied" error:
```bash
# Make sure you own the app file
sudo chown -R $(whoami) /Users/User/Documents/MyApp/MyApp.app
```

### DMG won't mount:
```bash
# Verify DMG integrity
hdiutil verify ~/Desktop/MyApp-1.0.0.dmg
```

### Download fails from website:
- Check file permissions are 644
- Verify file path is correct
- Check .htaccess doesn't block .dmg files

---

## Code Signing (Optional - For Professional Distribution)

To remove "unidentified developer" warnings:

```bash
# Sign your app with Apple Developer Certificate
codesign --deep --force --verify --verbose --sign "Developer ID Application: Your Name" /Users/User/Documents/MyApp/MyApp.app

# Then create DMG as usual
```

**Requirements:**
- Apple Developer Program membership ($99/year)
- Developer ID certificate from Apple

Your DMG is now ready for distribution! 🎉
