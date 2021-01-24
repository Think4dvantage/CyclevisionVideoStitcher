function create-Video {
    [CmdletBinding()]
    param (
        $Date,
        $Path,
        $Stitch,
        $Skip,
        $Short,
        $Solid,
        $Transparent,
        $StartBegin,
        $StartEnd,
        $LandingBegin,
        $LandingEnd,
        $Increment,
        $ClipLength
    )
    
    process 
    {
        if($Skip -eq $true)
        {
            write-host ("Folder " + $Path + " was Skipped due to SKIP Parameter!")
            return
        }

        #Path to the FFMPEG Binary (needs to be downloaded from ffmpeg)
        $ffmpegPath = $PSScriptRoot + "\ffmpeg\ffmpeg.exe"
        #Path to the FFProbe Binary (in the same download as the ffmpeg download)
        $ffmpegProbePath = $PSScriptRoot + "\ffmpeg\ffprobe.exe"
        #Path to the Output of the Stitching of FrontParts
        $frontOut = ($Path + "\" + $Date + "-Frontview.mp4")
        #Path to the Output of the Stitching of BackParts
        $backOut = ($Path + "\" + $Date + "-BackView.mp4")
        #Path to the Output of the Short Video
        $outputshort = $Path + "\" + $Date + "-short.mp4"
        #Transparent Video Output
        $outputtrans = ($Path + "\" + $Date + "-trans.mp4")
        #OutputSolid
        $outputsolid = ($Path + "\" + $Date + "-solid.mp4")
        
        $StartBegin = ([timespan]$StartBegin).TotalSeconds
        $StartEnd = ([timespan]$StartEnd).TotalSeconds
        $LandingBegin = ([timespan]$LandingBegin).TotalSeconds
        $LandingEnd = ([timespan]$LandingEnd).TotalSeconds
        $Increment = ([timespan]$Increment).TotalSeconds

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
        
        #Path to the Txt file containing the Parts for later Stitching
        $InputFilePath = ($Path + "\PartList.txt")

        #Check if Fronview and Backview Video have been Stitched together - if they are skip this Step
        if(!(test-path -path $frontout) -and !(test-path -path $backout))
        {
            #Trigger createInputFunction and write output to InputFilePath
            set-content -path $InputFilePath -Value (createInputfile $Path "F")
            #Stitch together all MP4 Files mentioned in the Input File Path
            start-process -FilePath $ffmpegPath -ArgumentList "-f concat -safe 0 -i $InputFilePath -c copy $frontOut -y" -PassThru -Wait -NoNewWindow
            #Trigger createInputFunction to get Backview Parts and write it to InputFile
            set-content -path $InputFilePath -Value (createInputfile $Path "B")
            #Stitch together the Rearview Input Files to one Big video
            start-process -FilePath $ffmpegPath -ArgumentList "-f concat -safe 0 -i $InputFilePath -c copy $backOut -y" -PassThru -Wait -NoNewWindow

            #Test if FrontView and Backview Video exist - if they exist delete the Sourcevideos
            if((test-path -path $frontout) -and (test-path -path $backout))
            {
                Remove-Item -Path ($Path + "\*") -Exclude ($Date + "*") -Recurse -Force
            }
        }
        else 
        {
            write-host ($Date + " - Front and Backout have been created skipping Stitching.")   
        }

        if($Stitch -eq $true)
        {
            Write-host ($Date + " - Stitch only is active progressing with next Folder!")
            return 
        }

        $tmpfront = ($path + "\frontlen")
        $tmpback = ($path + "\backlen")
        write-host "getting FronViewSize"
        start-process -FilePath $ffmpegProbePath -ArgumentList ("-v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 " + $frontOut) -NoNewWindow -RedirectStandardOutput $tmpfront
        write-host "getting Backviewsize"
        start-process -FilePath $ffmpegProbePath -ArgumentList ("-v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 " + $BackOut) -NoNewWindow -RedirectStandardOutput $tmpback
        start-sleep -seconds 1
        $frontViewSize = get-content -Path $tmpfront
        $BackViewSize = get-content -Path $tmpback
        if($frontViewSize -and $backviewSize)
        {
            remove-item -path $tmpfront
            remove-item -path $tmpback
        }
        #Create Value of Offset as a string to use it in the Arguments of the Blending Command
        write-host $BackviewSize
        write-host $frontviewSize
        if($BackViewSize -eq $frontViewSize -and $BackviewSize -gt 0 -and $Fronviewsize -gt 0)
        {
            Write-Host "Videos are of the same Length - no Offset needed!"
            $VideoOffset = "0.000"
        }
        else 
        {
            $VideoOffset = ($FrontViewSize - $BackViewSize).toString("#.###")
        }
        write-host ("videooffset1 ist: " + $videoOffset)
        #Make sure VideoOffset has 3 digits after the Comma 
        
        if($videoOffset -like "-*")
        {
            $videoOffset = "2.000"
        }
        
        if($VideoOffset.Length -ne 5)
        {
            switch ($VideoOffset.Length) {
                4 { $VideoOffset = $VideoOffset + "0" }
                3 { $VideoOffset = $VideoOffset + "00" }
                1 { $VideoOffset = $VideoOffset + ".000" }
                Default {$VideoOffset = "2.000" }
            }
        }

        write-host ("videooffset2 ist: " + $videoOffset)
        write-host "Starting ShortVideo"
        if($Short -eq $true -and !(test-path $outputshort))
        {
            write-host "got into the Shortvideo"
            if($StartEnd -le $StartBegin -or $LandingEnd -le $LandingBegin)
            {
                write-host $Date
                write-host $Path
                write-host $Stitch
                write-host $Skip
                write-host $Short
                write-host $Solid
                write-host $Transparent
                write-host $StartBegin
                write-host $StartEnd
                write-host $LandingBegin
                write-host $LandingEnd
                write-host $Increment
                write-host $ClipLength

                Write-host ($Date + " - Check StartBegin, StartEnd and so on")
                return
            }
            write-host "Starting to Create Arguments"
            $ffmpegarguments = ("-i $frontout -i $backout -filter_complex " + [char]34 + "[1]trim="+ ($startBegin-$VideoOffset) + ":" + ($StartEnd-$VideoOffset) +",setpts=PTS-STARTPTS[bs],[bs]scale=550:-1[bso];[0]atrim=" + $StartBegin + ":" + $StartEnd + ",asetpts=PTS-STARTPTS[ap1],[0]trim=" + $StartBegin + ":" + $StartEnd + ",setpts=PTS-STARTPTS[fv],[fv][bso] overlay=10:760[p1],")
            $parts = 1
            $partStart = $StartBegin + $Increment
            write-host "incrementing through parts"
            do {
                $parts++
                $partEnd = $partStart + $CLipLength
                $ffmpegarguments = ($ffmpegarguments + "[0]atrim=" + $partStart + ":" + $PartEnd +",asetpts=PTS-STARTPTS[ap"+ $parts +"]," + "[0]trim=" + $partStart + ":" + $PartEnd +",setpts=PTS-STARTPTS[p"+ $parts +"],")
                $partStart = $partStart + $Increment
            } while ($PartStart -lt $LandingBegin)
            $Parts += 1
            write-host "Parts created, create end of Video"
            $ffmpegarguments = ($ffmpegarguments + "[0]atrim=" + $LandingBegin + ":" + $LandingEnd + ",asetpts=PTS-STARTPTS[ap"+ $parts +"],[0]trim=" + $LandingBegin + ":" + $LandingEnd + ",setpts=PTS-STARTPTS[p"+ $parts +"],")
            $i = 1
            do {
                $ffmpegarguments = ($ffmpegarguments + "[p" + $i + "][ap" + $i + "]")
                $i++ 
                
            } while ($i -lt $parts)
            $ffmpegarguments = ($ffmpegarguments + "[p" + $parts + "][ap" + $parts + "]concat=n=" + $parts + ":v=1:a=1[out][aout]" + [char]34 + " -map " + [char]34 + "[out]" + [char]34 + " -map " + [char]34 + "[aout]" + [char]34 +" $outputshort -filter:a loudnorm -hwaccel cuda -hwaccel_output_format cuda -y")
            
            $VidLength = [timespan]::fromseconds([int]($StartEnd - $StartBegin) + ((($LandingBegin - $StartEnd)/$Increment)*15) + ($LandingEnd - $LandingBegin))
            Write-Host ($Date + " - The Video will be approximately " + $VidLength.ToString("hh\:mm\:ss") + " Long:")

            start-process -FilePath $ffmpegPath -ArgumentList $ffmpegarguments -PassThru -wait -nonewWindow
        }#End ShortVideo
        

    }#End Process
    
}

write-host "NewVideoCombiner imported"

<#
$DO = @{
    Date = "202008074"
    Path = "D:\Cyclevision\2020.08.07.4"
    Stitch = $false
    Short = $true
    Solid = $false
    Transparent = $false
    StartBegin = "00:00:10"
    StartEnd = "00:01:11"
    LandingBegin = "00:02:10"
    LandingEnd = "00:02:40"
    Increment = "00:00:30"
    ClipLength = "15"
}


create-Video @DO
#>