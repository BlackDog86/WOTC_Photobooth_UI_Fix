class UIPoseFix_SaveLayout extends object config(PoseFixLayout);

var config int				SavedLayoutTemplateIndex;
var config int				NumberOfNonBlankLinesInSavedLayout;
var config int				NumberOfNonBlankLinesInCurrentLayout;
var config array<string>	PosterFonts;
var config array<int>		PosterStringColors;
var config bool				bIsFirstLineBline;
var config string			lastBline;
var config string			lastAline;
var config string			lastOpline;
var config bool				hasOpline;

static function SaveLayoutConfigs()
{
	StaticSaveConfig();
}

static function ClearArrays()
{	
	default.PosterFonts.Length = 0;
	default.PosterStringColors.Length = 0;	
	SaveLayoutConfigs();
}
