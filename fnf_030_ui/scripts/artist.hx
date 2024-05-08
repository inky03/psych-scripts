var artist_KS:String = 'Kawai Sprite';
var artist_basset:String = 'BassetFilms';
var artist_KSsaru:String = 'Kawai Sprite (feat. Saruky)';
var artist_fallback:Map = [
	//to avoid this whole fuss,
	//just add a tag "artist" to your song .json
	'bopeebo' => artist_KS,			'fresh' => artist_KS,		'dadbattle' => artist_KS,
	'spookeez' => artist_KS,		'south' => artist_KS,		'monster' => artist_basset,
	'pico' => artist_KS,			'philly nice' => artist_KS,	'blammed' => artist_KS,
	'satin panties' => artist_KS,	'high' => artist_KS,		'milf' => artist_KS,
	'cocoa' => artist_KS,			'eggnog' => artist_KS,		'winter horrorland' => artist_basset, //there was a mistake in 0.3.0
	'senpai' => artist_KS,			'roses' => artist_KS,		'thorns' => artist_KS,
	'ugh' => artist_KS,				'guns' => artist_KS,		'stress' => artist_KS,
	'darnell' => artist_KS,			'lit up' => artist_KS,		'2hot' => artist_KS, 'blazin' => artist_KS,
	//erect
	'bopeebo erect' => artist_KSsaru,
	'fresh erect' => 'Kohta Takahashi (feat. Saruky)',
	'dadbattle erect' => artist_KS,
	'spookeez erect' => artist_KSsaru,
	'south erect' => artist_KSsaru,
	'pico erect' => artist_KSsaru,
	'philly nice erect' => artist_KSsaru,
	'blammed erect' => artist_KS,
	'high erect' => 'Kohta Takahashi (feat. Kawai Sprite)',
	'senpai erect' => 'Kawaisprite', //why would you do that
	'roses erect' => artist_KS,
	'thorns erect' => 'Kawai Sprite (feat. Saster)',
];

function onCreate() {
	if (PlayState.SONG.artist == null) PlayState.SONG.artist = artist_fallback.get(PlayState.SONG.song.toLowerCase()); //if this is also null nothing changes :P
	return Function_Continue;
}