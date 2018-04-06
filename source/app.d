import dsfml.system;
import dsfml.window;
import dsfml.graphics;
import dsfml.audio;
import std.utf;
import std.random;
import std.conv;
import std.stdio;
import std.json;
import std.file;

immutable string[] symbols = ["\u30a0", "\u30a1", "\u30a2", "\u30a3", "\u30a4", "\u30a5", "\u30a6", "\u30a7",
 "\u30a8", "\u30a9", "\u30aa", "\u30ab", "\u30ac", "\u30ad", "\u30ae", "\u30af", "\u30b0", "\u30b1", "\u30b2",
 "\u30b3", "\u30b4", "\u30b5", "\u30b6", "\u30b7", "\u30b8", "\u30b9", "\u30ba", "\u30bb", "\u30bc", "\u30bd",
 "\u30be", "\u30bf", "\u30c0", "\u30c1", "\u30c2", "\u30c3", "\u30c4", "\u30c5", "\u30c6", "\u30c7", "\u30c8",
 "\u30c9", "\u30ca", "\u30cb", "\u30cc", "\u30cd", "\u30ce", "\u30cf", "\u30d0", "\u30d1", "\u30d2", "\u30d3",
 "\u30d4", "\u30d5", "\u30d6", "\u30d7", "\u30d8", "\u30d9", "\u30da", "\u30db", "\u30dc", "\u30dd", "\u30de",
 "\u30df", "\u30e0", "\u30e1", "\u30e2", "\u30e3", "\u30e4", "\u30e5", "\u30e6", "\u30e7", "\u30e8", "\u30e9",
 "\u30ea", "\u30eb", "\u30ec", "\u30ed", "\u30ee", "\u30ef", "\u30f0", "\u30f1", "\u30f2", "\u30f3", "\u30f4",
 "\u30f5", "\u30f6", "\u30f7", "\u30f8", "\u30f9", "\u30fa", "\u30fb", "\u30fc", "\u30fd", "\u30fe"];

Random rng;

class Symbol
{
	Vector2f pos;
	Text t;
	int start;
	int lifespan;
	int num;
	Color color;
	int charWidth;
	string[] colors;
	int chance;

	this(Vector2f *pos, int start, int width, string[] colors, Font font, int chance, int lifespan)
	{
		this.charWidth = width;
		this.pos = *pos;
		this.t = new Text("", font, this.charWidth);
		changeCurrent();
		this.color = Color(255, 255, 255, 255);
		this.t.setColor(this.color);
		this.t.position(this.pos);
		this.start = start;
		this.colors = colors;
		this.chance = chance;
		this.lifespan = lifespan;
	}

	void changeCurrent()
	{
		int chance = uniform(0, 5, rng);
		if (chance < 1)
			this.t.setString(to!string(cast(char) uniform(48, 57, rng)));
		else
			this.t.setString(symbols[uniform(1, symbols.length - 1, rng)]);
	}
	
	void update(int frames, int chance, int rate)
	{
		if (frames - this.start > 0)
			if (uniform(0, this.chance, rng) == 0)
				this.changeCurrent();
		this.t.setColor(this.color);
		if (this.color.a > rate && this.lifespan <= 0)
			this.color.a -= rate;
		if (this.lifespan > 0)
			this.lifespan -= rate;
		if (frames % chance == 0 && this.color.r > 0)
		{
			foreach (c; this.colors)
			{
				if (c == "g")
					this.color.g -= 85;
				else if (c == "b")
					this.color.b -= 85;
				else if (c == "r")
					this.color.r -= 85;
			}
		}
	}
}

class Stream
{
	Vector2f pos;
	Symbol[] symbols;
	int length;
	int total = 0;
	int y;
	int charWidth;
	string[] colors;

	this(int x, int width, string[] colors)
	{
		this.y = uniform(-2000, 0, rng);
		this.pos.x = x;
		this.pos.y = y;
		this.charWidth = width;
		this.length = width;
		this.colors = colors;
	}

	void draw(RenderWindow window)
	{
		foreach (sym; symbols)
			window.draw(sym.t);
	}

	void update(int frames, ulong c, int height, Font font, int chance, int framesToChange, int lifespan, int rate)
	{
		foreach (i; 0 .. symbols.length)
		{
			symbols[i].update(frames, framesToChange, rate);
		}
		if (frames % framesToChange == 0 && pos.y <= height)
		{
			if (pos.y >= -this.charWidth)
			{
				symbols ~= new Symbol(new Vector2f(pos.x, pos.y), frames, this.charWidth, this.colors, font, chance, lifespan);
				total++;
			}
			pos.y += charWidth;
		}
		else
		{
			bool done = false;
			foreach (i; 0 .. symbols.length)
			{
				if (symbols[i].color.a < rate)
					done = true;
				else
					done = false;
			}
			if (done)
			{
				foreach(i; 0 .. symbols.length)
					delete symbols[i];
				symbols.length = 0;
				pos.y = this.y;
			}
		}
	}
}

void main()
{
	//Parse the config
	auto config = parseJSON(readText("conf.json"));
	int charWidth = cast(int) config["charsize"].integer;
	int framerate = cast(int) config["fps"].integer;
	int showFrames = cast(int) config["showframes"].integer;
	int chance = cast(int) config["chance"].integer;
	int framesToChange = cast(int) config["framestochange"].integer;
	int lifespan = cast(int) config["lifespan"].integer;
	int rate = cast(int) config["rate"].integer;
	string[] colors;
	foreach (c; config["color"].array)
		colors ~= c.str;
	writeln(colors);

	//Create array for streams, and a random generator.
	int frames;
	int prevFrames;
	Stream[] streams;
	rng = Random(unpredictableSeed);

	//Create FPS stuff
	Font font = new Font();
	font.loadFromFile("Kata.ttf");
	Text text = new Text("", font, 40);
	auto time = MonoTime.currTime;

	//Get the width and height of the current display
	int width = VideoMode.getDesktopMode().width;
	int height = VideoMode.getDesktopMode().height;
	writeln("Width: " ~ to!string(width) ~ " Height: " ~ to!string(height));

	//Create a sfml RenderWindow and set the max framerate to 30
	auto window = new RenderWindow(VideoMode(width, height), "Matrix");
	window.setFramerateLimit(framerate);

	//Create all the streams and add them to streams. Set the x of all the streams to i * charWidth
	foreach (i; 0 .. (width / charWidth))
		streams ~= new Stream(i * charWidth, charWidth, colors);
	
	while (window.isOpen())
	{
		Event event;
		if (showFrames)
		{
			auto curr = (MonoTime.currTime - time);
			if (curr >= 1.seconds)
			{
				time = MonoTime.currTime;
				text.setString(to!string(frames - prevFrames));
				prevFrames = frames;
			}
		}
		while (window.pollEvent(event))
		{
			if (event.type == Event.EventType.Closed)
				window.close();
		}
		window.clear(Color.Black);
		foreach (i; 0 .. streams.length)
		{
			streams[i].update(frames, i, height, font, chance, framesToChange, lifespan, rate);
			streams[i].draw(window);
		}
		window.draw(text);
		window.display();
		frames++;
	}
}
