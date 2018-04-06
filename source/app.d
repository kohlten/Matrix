import std.random;
import std.conv;
import std.stdio;
import std.json;
import std.file;
import dsfml.system;
import dsfml.window;
import dsfml.graphics;
import dsfml.audio;

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

	this(Vector2f pos, int start, int width, string[] colors, Font font, int chance, int lifespan)
	{
		this.charWidth = width;
		this.pos = pos;
		this.t = new Text("", font, this.charWidth);
		this.color = Color(255, 255, 255, 255);
		this.t.setColor(this.color);
		this.t.position(this.pos);
		this.start = start;
		this.colors = colors;
		this.chance = chance;
		this.lifespan = lifespan;
		changeCurrent();
	}
	
	//Change the symbol randomly.
	//Change the alpha based on rate and if lifespan is 0. 
	//For every update, change the color of the symbol.
	void update(int frames, int chance, int rate)
	{
		if (frames - this.start > 0)
			if (uniform(0, this.chance, rng) == 0)
				this.changeCurrent();
		if (this.color.a > rate && this.lifespan <= 0)
			this.color.a -= rate;
		if (this.lifespan > 0)
			this.lifespan -= rate;
		if (frames % chance == 0 && this.color.r > 0)
			this.changeColor();
		this.t.setColor(this.color);
	}

	//Minus the current color based on colors from the conf
	void changeColor()
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

	//Generate a new random symbol.
	//If the chance is less than 1 make it a number.
	//Else, get a random katakana character.
	void changeCurrent()
	{
		int chance = uniform(0, 5, rng);
		if (chance < 1)
			this.t.setString(to!string(cast(dchar) uniform(48, 57, rng)));
		else
			this.t.setString(to!string(cast(dchar) (12448 + uniform(0, 95))));
	}
}

class Stream
{
	Vector2f pos;
	Symbol[] symbols;
	int length;
	int total;
	int y;
	int charWidth;
	string[] colors;

	this(int x, int width, string[] colors, int spacing)
	{
		this.y = uniform(spacing, 0, rng);
		this.pos.x = x;
		this.pos.y = y;
		this.charWidth = width;
		this.length = width;
		this.colors = colors;
	}

	//For each of the symbols, draw them to window
	void draw(RenderWindow window)
	{
		foreach (sym; symbols)
			window.draw(sym.t);
	}

	//For all the symbols, update them. Every framesToChange create a new symbol and add it to symbols
	//When all the symbols have gone invisible, delete all the symbols and start again
	void update(int frames, ulong c, int height, Font font, int chance, int framesToChange, int lifespan, int rate)
	{
		foreach (i; 0 .. this.symbols.length)
		{
			this.symbols[i].update(frames, framesToChange, rate);
		}
		if (frames % framesToChange == 0 && this.pos.y <= height)
			this.createNewSymbol(frames, font, chance, lifespan);
		else
			if (this.seeIfDone(rate))
				this.startNew();
	}

	//Generate a new symbol and add it to symbols.
	//Then move down charWidth pixels
	void createNewSymbol(int frames, Font font, int chance, int lifespan)
	{
		if (this.pos.y >= -this.charWidth)
		{
			this.symbols ~= new Symbol(Vector2f(this.pos.x, this.pos.y), frames, this.charWidth, this.colors, font, chance, lifespan);
			this.total++;
		}
		this.pos.y += this.charWidth;
	}

	//Check if all the symbols are invisible.
	bool seeIfDone(int rate)
	{
		bool done;
		foreach (i; 0 .. this.symbols.length)
		{
			if (this.symbols[i].color.a < rate)
				done = true;
			else
				done = false;
		}
		return done;
	}

	//Delete all symbols and reset back to the beginning.
	void startNew()
	{
		foreach(i; 0 .. this.symbols.length)
			delete this.symbols[i];
		this.symbols.length = 0;
		this.pos.y = this.y;
	}

	//Return the current amount of symbols
	ulong getTotal()
	{
		return symbols.length;
	}
}

void main()
{
	//Parse the config
	string[] colors;
	auto config = parseJSON(readText("conf.json"));

	int charWidth = cast(int) config["charsize"].integer;
	int framerate = cast(int) config["fps"].integer;
	int showFrames = cast(int) config["showframes"].integer;
	int chance = cast(int) config["chance"].integer;
	int framesToChange = cast(int) config["framestochange"].integer;
	int lifespan = cast(int) config["lifespan"].integer;
	int rate = cast(int) config["rate"].integer;
	int spacing = cast(int) config["spacing"].integer;

	foreach (c; config["color"].array)
		colors ~= c.str;

	//Create array for streams, and a random generator.
	int frames;
	int prevFrames;
	Stream[] streams;
	rng = Random(unpredictableSeed);

	//Create FPS stuff
	Font font = new Font();
	font.loadFromFile("Kata.ttf");
	Text fps = new Text("", font, 40);
	Text amount = new Text("0", font, 40);
	auto time = MonoTime.currTime;

	//Get the width and height of the current display
	int width = VideoMode.getDesktopMode().width;
	int height = VideoMode.getDesktopMode().height;
	writeln("Width: " ~ to!string(width) ~ " Height: " ~ to!string(height));

	//Set the amount position to 80 pixels from the right the display
	amount.position = Vector2f(width - 80, 0);

	//Create a sfml RenderWindow and set the max framerate to 30
	auto window = new RenderWindow(VideoMode(width, height), "Matrix");
	window.setFramerateLimit(framerate);

	//Create all the streams and add them to streams. Set the x of all the streams to i * charWidth
	foreach (i; 0 .. (width / charWidth))
		streams ~= new Stream(i * charWidth, charWidth, colors, spacing);
	
	while (window.isOpen())
	{
		//fps stuff
		if (showFrames)
		{
			auto curr = (MonoTime.currTime - time);
			if (curr >= 1.seconds)
			{
				time = MonoTime.currTime;
				fps.setString(to!string(frames - prevFrames));
				prevFrames = frames;
			}
			ulong totalSymbols;
			foreach (stream; streams)
				totalSymbols += stream.getTotal();
			amount.setString(to!string(totalSymbols));
		}

		//Parse events
		Event event;
		while (window.pollEvent(event))
		{
			if (event.type == Event.EventType.Closed)
				window.close();
		}

		//Clear the window with the color black
		window.clear(Color.Black);

		//For each of the streams, update them and draw them
		foreach (i; 0 .. streams.length)
		{
			streams[i].update(frames, i, height, font, chance, framesToChange, lifespan, rate);
			streams[i].draw(window);
		}

		//Draw the fps and the current amount of symbols
		window.draw(fps);
		window.draw(amount);

		//Update the window
		window.display();
		frames++;
	}
}
