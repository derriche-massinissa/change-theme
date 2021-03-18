#!/bin/sh

##
## Defining defaults ########################################
##
# Script name, used for the help message
SCRNAME="chtheme"
#
# Input and output files
#
inImage="$HOME/.config/wall"
outMain="$HOME/.config/wall"
outTerm="$HOME/.config/wall0"
outBlur="$HOME/.config/wall1.png"
imgDisplaced="$HOME/.config/wall2.png"
generateImage="false"
#
# Blur parameters
#
density=5
spread=5
bluramt=15
opacity=50%
#
# Pywal variables
# Possible values: wal, colorz, colorthief, haishoku, schemer2
walBackend=wal
#
# Temporary textures
#
tmpNoise="_noise_.jpg"
resolution=$(xdpyinfo | grep dimensions | awk '{print $2;}')

##
## Usage functions
##
availableBackends() {
    echo "Available backends:"
    echo " - wal"
    echo " - colorz"
    echo " - colorthief"
    echo " - haishoku"
    echo " - schemer2"
}
usage() {
    echo "usage: $SCRNAME [-h] [-i /path/to/image] [-b backend]"
    echo "               [-D density] [-S spread] [-B bluramt]"
	echo "               [-O opacity (%)]"
    availableBackends
}

##
## Getting options ########################################
##
while getopts ":i:b:D:S:B:O:h" opts; do
    case $opts in
        i) if [ ! -f $OPTARG ]; then
                echo "Image file not found"
                exit 0
            fi
            inImage=$OPTARG
            generateImage="true"
            ;;
        b) case $OPTARG in
                a|1|"wal")          walBackend="wal";;
                b|2|"colorz")       walBackend="colorz";;
                c|3|"colorthief")   walBackend="colorthief";;
                d|4|"haishoku")     walBackend="haishoku";;
                e|5|"schemer2")     walBackend="schemer2";;
                *) echo "Uncorrect backend"
                    availableBackends
                    echo "Using 'wal' backend per default"
                    ;;
            esac
            ;;
        D) density=$OPTARG;;
        S) spread=$OPTARG;;
        B) bluramt=$OPTARG;;
        O) opacity=$OPTARG;;
        h) usage
            exit 0
            ;;
        *) usage
            exit 0
            ;;
    esac
done

##
## Generate alternate images (Blured and frosted) ########################################
##
if [ "$generateImage" == "true" ]; then
    #
    # Resize image to screen size (Fill mode)
    #
    echo "Resizing image to screen resolution"
    convert "$inImage" -resize "$resolution^" -gravity center -extent "$resolution" "$outMain"
    #convert "$inImage" -resize "1600x900^" -gravity center -extent 1600x900 "$outMain"
    #
    # Blur image
    #
    echo "Applying a bluring effect"
    convert -quiet "$outMain" -blur 0x${bluramt} +repage "$outBlur"
    #
    # Generate noise texture
    #
    echo "Generating noise texture"
    convert -size 1600x900 xc:gray +noise random \
            -virtual-pixel tile \
            -colorspace gray -contrast-stretch 0%  $tmpNoise
    #
    # Use generated noise texture as a displacement map
    #
    echo "Displacing image with the noise texture (Frosted Glass Effect)"
    convert $tmpNoise -colorspace sRGB\
            -channel R -evaluate sine $density \
            -channel G -evaluate cosine $density \
            -channel RG -separate $outBlur -insert 0 \
            -colorspace sRGB -define compose:args=${spread}x${spread} \
            -compose displace -composite "$imgDisplaced"

    ##
    ## Cleaning up
    ##
    rm $tmpNoise
elif [ ! -f "$outMain" ] || [ ! -f "$outTerm" ] || [ ! -f "$outBlur" ] || [ ! -f "$imgDisplaced" ]; then
    echo "No image in cache"
    usage
    exit 0;
fi

##
## Pywal
##
echo "Starting Pywal"
wal -c
wal -i "$outMain" --backend "$walBackend"

##
## Overlay with background color
##
echo "Darkening the image with background color"
convert -quiet $imgDisplaced -fill $(xrdb -query | grep "*.background" | grep -o '.......$') -colorize $opacity "$outTerm"

##
## Update bspwm
##
## Uncomment the following two lines to refresh the bspwm tiling manager
#echo "Updating Bspwm"
#bspc wm -r

##
## Update already running instances of st
##
## Uncomment the following two lines to update running st instances
#echo "Updating already running instances of st (Xlib XSendEvent)"
#st-bg-event
