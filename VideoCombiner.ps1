#This Function does all the Work - Stitches Together the Backview and FrontView and then Puts the Backview as smaller overlay to the FrontView Video
function CreateCamVideo($InputFolder)
{
    #Function to create Input File for Video Stitching - I somehow didn't get it to work with a Variable.
    function createInputfile($Path, $View)
    {
        #Prepare Output Var
        $out = @()
        #Get Filenames from Folder - Either F_ for frontview or B_ for Backview
        $FileNames = (get-childitem -Path $Path\* -Include ($View + "_*")).Versioninfo.Filename
        #Go trough every File and add it to the Output Array
        foreach($file in $filenames)
        {
            $out += ("file '" + $file + "'") 
        }
        #Return the Files collected
        return $out
    }
    #Get Record Date for Video Output naming
    $RecordDate = ((get-childitem -Path $InputFolder\* -Include ("F_*"))[0].LastWriteTime).ToString("yyyy-MM-dd")
    #Path to the Txt file containing the Parts for later Stitching
    $InputFilePath = ($InputFolder + "\PartList.txt")
    #Path to the Output of the Stitching of FrontParts
    $frontOut = ($InputFolder + "\Frontview.mp4")
    #Path to the Output of the Stitching of BackParts
    $backOut = ($InputFolder + "\BackView.mp4")
    #Generate Output path for the Blended Video
    $outputpath = ($InputFolder + "\" + $RecordDate + ".mp4")
    #Path to the FFMPEG Binary (needs to be downloaded from ffmpeg)
    $ffmpegPath = "C:\Program Files\ffmpeg\ffmpeg.exe"
    #Path to the FFProbe Binary (in the same download as the ffmpeg download)
    $ffmpegProbePath = "C:\Program Files\ffmpeg\ffprobe.exe"
    #Trigger createInputFunction and write output to InputFilePath
    set-content -path $InputFilePath -Value (createInputfile $InputFolder "F")
    #Stitch together all MP4 Files mentioned in the Input File Path
    start-process -FilePath $ffmpegPath -ArgumentList "-f concat -safe 0 -i $InputFilePath -c copy $frontOut -y" -PassThru -Wait -NoNewWindow
    #Trigger createInputFunction to get Backview Parts and write it to InputFile
    set-content -path $InputFilePath -Value (createInputfile $InputFolder "B")
    #Stitch together the Rearview Input Files to one Big video
    start-process -FilePath $ffmpegPath -ArgumentList "-f concat -safe 0 -i $InputFilePath -c copy $backOut -y" -PassThru -Wait -NoNewWindow

    #Get FrontView Video length by using ffprobe - to get an Idea what offset the Videos have (its everytime different) had to use cmd cause start-process wouldn't deliver me the return
    $frontViewSize = cmd /c ([char]34 + "$ffmpegProbePath" + [char]34 + " -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 " + $frontOut)
    #Get Backview Video length to see how much the Backview video needs to be delayed
    $BackViewSize = cmd /c ([char]34 + "$ffmpegProbePath" + [char]34 + " -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 " + $BackOut)
    #Create Value of Offset as a string to use it in the Arguments of the Blending Command
    $VideoOffset = ($FrontViewSize - $BackViewSize).toString("#.###")
    #Make sure VideoOffset has 3 digits after the Comma 
    if($VideoOffset.Length -ne 5)
    {
        switch ($VideoOffset.Length) {
            4 { $VideoOffset = $VideoOffset + "0" }
            3 { $VideoOffset = $VideoOffset + "00" }
            1 { $VideoOffset = $VideoOffset + ".000" }
            Default {$VideoOffset = "2.000" }
        }
    }
    #Output the Offset - for purposes
    write-host ("Video Offset is: " + $VideoOffset)
    #Prepare FFMPEG Arguments to Blend the two videos together
    $ffmpegarguments = ("-i $frontout -itsoffset 00:00:0$VideoOffset -i $backout -filter_complex " + [char]34 + "[1:v] scale=550:-1, pad=1920:1080:ow-iw-1360:oh-ih-10, setsar=sar=1, format=rgba [bs]; [0:v] setsar=sar=1, format=rgba [fb]; [fb][bs] blend=all_mode=addition:all_opacity=0.7" + [char]34 + " -vcodec libx265 -crf 28 $outputpath -hwaccel cuda -hwaccel_output_format cuda -y")
    #Blend FrontView and Backview together
    start-process -FilePath $ffmpegPath -ArgumentList $ffmpegarguments -PassThru -wait -nonewWindow
}
#Define Folder where to search for subfolders with Recordings
$SurveilanceFolder = "C:\Cyclevision\"
#Foreach Folder in C:\Cyclevision - start the Function to create a Video
foreach($folder in (get-childitem -path $SurveilanceFolder))
{
    #Create path to Folder
    $fp = ($SurveilanceFolder + $folder.Name)
    #Check if partlist.txt already exists - if it exists no Video creation needed
    if((get-childitem -path $fp).Name -notcontains "Partlist.txt")
    {
        CreateCamVideo $fp
    }
    else 
    {
        Write-host "Video already produced - i guess"    
    }
}
Write-host "Videocreation has finished" -BackgroundColor green
