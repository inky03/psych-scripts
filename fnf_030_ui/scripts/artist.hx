var artist_KS:String = 'Kawai Sprite';
var artist_basset:String = 'BassetFilms';
var artist_KSsaru:String = 'Kawai Sprite (feat. Saruky)';
var artist_fallback:Map = [
	// to avoid this whole fuss,
	// just add a tag "artist" to your song .json
	'tutorial' => artist_KS,
	'bopeebo' => artist_KS,			'fresh' => artist_KS,		'dadbattle' => artist_KS,
	'spookeez' => artist_KS,		'south' => artist_KS,		'monster' => artist_basset,
	'pico' => artist_KS,			'philly nice' => artist_KS,	'blammed' => artist_KS,
	'satin panties' => artist_KS,	'high' => artist_KS,		'milf' => artist_KS,
	'cocoa' => artist_KS,			'eggnog' => artist_KS,		'winter horrorland' => artist_basset,
	'senpai' => artist_KS,			'roses' => artist_KS,		'thorns' => artist_KS,
	'ugh' => artist_KS,				'guns' => artist_KS,		'stress' => artist_KS,
	'darnell' => artist_KS,			'lit up' => artist_KS,		'2hot' => artist_KS, 		'blazin\'' => artist_KS,
];

var charter_nM:String = 'ninjamuffin99 + MtH';
var charter_fallback:Map = [
	// same thing as artist, but with the "charter" tag instead!
	'tutorial' => charter_nM,
	'bopeebo' => charter_nM,		'fresh' => charter_nM,		'dadbattle' => charter_nM,
	'spookeez' => 'ninjamuffin99 + MtH + SpazKid', 'south' => charter_nM, 'monster' => 'ChaoticGamerCG + Spazkid',
	'pico' => charter_nM,			'philly nice' => charter_nM,'blammed' => charter_nM,
	'satin panties' => charter_nM,	'high' => charter_nM,		'milf' => charter_nM,
	'cocoa' => charter_nM,			'eggnog' => charter_nM,		'winter horrorland' => charter_nM,
	'senpai' => charter_nM,			'roses' => charter_nM,		'thorns' => charter_nM,
	'ugh' => null,					'guns' => 'MtH',			'stress' => 'MtH + SpazKid',
	'darnell' => charter_nM, 'lit up' => 'Jenny Crowe + Spazkid', '2hot' => 'Jenny Crowe + Spazkid + ninjamuffin99', 'blazin\'' => 'fabs + PhantomArcade',
];

function onCreate() {
	if (PlayState.SONG.artist == null)
		PlayState.SONG.artist = artist_fallback.get(PlayState.SONG.song.toLowerCase()); //if this is also null nothing changes :P
	if (PlayState.SONG.charter == null)
		PlayState.SONG.charter = charter_fallback.get(PlayState.SONG.song.toLowerCase());
	return;
}