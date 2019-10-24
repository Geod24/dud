module dud.sdlang2.lexer;

import std.ascii : isWhite;
import std.array : appender, empty, front, popFront, popBack;
import std.algorithm.searching : startsWith;
import std.base64;
import std.experimental.logger;
import std.format : format;
import std.typecons : Flag;
import std.stdio;

import dud.sdlang2.tokenmodule;
import dud.sdlang2.value;

struct Lexer {
	string input;

	size_t line;
	size_t column;

	Token cur;

	this(string input) @safe {
		this.input = input;
		this.line = 1;
		this.column = 1;
		this.buildToken();
	}

	private bool eatComment() @safe {
		if(this.input.startsWith("#") || this.input.startsWith("--")
				|| this.input.startsWith("//"))
		{
			while(!this.input.startsWith('\n')) {
				++this.column;
				this.input.popFront();
			}
			++this.line;
			this.column = 1;
			return true;
		} else if(this.input.startsWith("/*")) {
			while(!this.input.startsWith("*/")) {
				if(this.input.startsWith('\n')) {
					++this.line;
					this.column = 1;
				} else {
					++this.column;
				}
				this.input.popFront();
			}
			return true;
		}
		return false;
	}

	private void eatWhitespace() @safe {
		while(!this.input.empty) {
			if(this.eatComment()) {
				continue;
			} else if(this.input.front == ' ') {
				++this.column;
			} else if(this.input.front == '\t') {
				++this.column;
			} else if(this.input.front == '\n') {
				this.column = 1;
				++this.line;
			} else {
				break;
			}
			this.input.popFront();
		}
	}

	private void singleCharToken(TokenType tt) @safe {
		this.cur = Token(tt, this.line, this.column);
		++this.column;
		this.input.popFront();
	}

	private void buildToken() @safe {
		this.eatWhitespace();

		if(this.input.empty) {
			this.cur = Token(TokenType.undefined);
			return;
		}

		if(this.input.front == '{') {
			this.singleCharToken(TokenType.lcurly);
			return;
		} else if(this.input.front == '}') {
			this.singleCharToken(TokenType.rcurly);
			return;
		} else if(this.input.front == '=') {
			this.singleCharToken(TokenType.assign);
			return;
		} else if(this.input.front == ':') {
			this.singleCharToken(TokenType.colon);
			return;
		} else if(this.input.front == '\\') {
			this.singleCharToken(TokenType.backslash);
			return;
		} else if(this.input.front == ';') {
			this.singleCharToken(TokenType.semicolon);
			return;
		} else if(this.input.front == '[') {
			size_t l = this.line;
			size_t c = this.column;
			++this.column;
			this.input.popFront();

			size_t rbrack;
			while(rbrack < this.input.length && this.input[rbrack] != ']') {
				++rbrack;
				++this.column;
			}

			++this.column;

			string theData = this.input[0 .. rbrack];
			ubyte[] data = Base64.decode(theData);
			this.input = this.input[rbrack + 1 .. $];
			this.cur = Token(TokenType.value, Value(data), theData, l, c);
			return;
		} else if(this.input.front == '`') {
			size_t l = this.line;
			size_t c = this.column;
			++this.column;
			this.input.popFront();

			auto app = appender!string();

			while(this.input.front != '`') {
				app.put(this.input.front);
				if(this.input.front == '\n') {
					++this.line;
					this.column = 1;
				} else {
					++this.column;
				}
				this.input.popFront();
			}

			assert(this.input.front == '`', this.input);
			this.input.popFront();


		} else if(this.input.front == '"') {
			size_t l = this.line;
			size_t c = this.column;
			++this.column;
			this.input.popFront();

			auto app = appender!string();

			while(!this.input.startsWith('"')) {
				if(this.input.length > 1 && this.input.front == '\\') {
					this.input.popFront();
					if(this.input.front == '"') {
						app.put('"');
						this.column += 2;
						this.input = this.input[2 .. $];
						continue;
					} else {
						while(this.input.front.isWhite()) {
							if(this.input.front == ' ') {
								++this.column;
							} else if(this.input.front == '\t') {
								++this.column;
							} else if(this.input.front == '\n') {
								++this.line;
								this.column = 1;
							}
							this.input.popFront();
						}
						continue;
					}
				} else {
					app.put(this.input.front);
					++this.column;
					this.input.popFront();
				}
			}
			assert(this.input.front == '"', this.input);
			this.input.popFront();
			++this.column;

			this.cur = Token(TokenType.value, Value(app.data), app.data, l, c);
			return;
		}
	}

	/*private void buildToken() @safe {
		import std.ascii : isAlphaNum;
		this.eatWhitespace();

		if(this.stringPos >= this.input.length) {
			this.cur = Token(TokenType.undefined);
			return;
		}

		if(this.input[this.stringPos] == ')') {
			this.cur = Token(TokenType.rparen, this.line, this.column);
			++this.column;
			++this.stringPos;
		} else if(this.input[this.stringPos] == '(') {
			this.cur = Token(TokenType.lparen, this.line, this.column);
			++this.column;
			++this.stringPos;
		} else if(this.input[this.stringPos] == ']') {
			this.cur = Token(TokenType.rbrack, this.line, this.column);
			++this.column;
			++this.stringPos;
		} else if(this.input[this.stringPos] == '[') {
			this.cur = Token(TokenType.lbrack, this.line, this.column);
			++this.column;
			++this.stringPos;
		} else if(this.input[this.stringPos] == '}') {
			this.cur = Token(TokenType.rcurly, this.line, this.column);
			++this.column;
			++this.stringPos;
		} else if(this.input[this.stringPos] == '$') {
			this.cur = Token(TokenType.dollar, this.line, this.column);
			++this.column;
			++this.stringPos;
		} else if(this.input[this.stringPos] == '!') {
			this.cur = Token(TokenType.exclamation, this.line, this.column);
			++this.column;
			++this.stringPos;
		} else if(this.input[this.stringPos] == '{') {
			this.cur = Token(TokenType.lcurly, this.line, this.column);
			++this.column;
			++this.stringPos;
		} else if(this.input[this.stringPos] == '|') {
			this.cur = Token(TokenType.pipe, this.line, this.column);
			++this.column;
			++this.stringPos;
		} else if(this.input[this.stringPos] == '@') {
			this.cur = Token(TokenType.at, this.line, this.column);
			++this.column;
			++this.stringPos;
		} else if(this.input[this.stringPos] == ',') {
			this.cur = Token(TokenType.comma, this.line, this.column);
			++this.column;
			++this.stringPos;
		} else if(this.input[this.stringPos] == '=') {
			this.cur = Token(TokenType.equal, this.line, this.column);
			++this.column;
			++this.stringPos;
		} else if(this.input[this.stringPos] == ':') {
			this.cur = Token(TokenType.colon, this.line, this.column);
			++this.column;
			++this.stringPos;
		} else {
			size_t b = this.stringPos;
			size_t e = this.stringPos;
			switch(this.input[this.stringPos]) {
				case 'm':
					++this.stringPos;
					++this.column;
					++e;
					if(this.testStrAndInc!"utation"(e)) {
						if(this.isTokenStop()) {
							this.cur = Token(TokenType.mutation, this.line,
										this.column);
							return;
						}
					}
					goto default;
				case 's':
					++this.stringPos;
					++this.column;
					++e;
					if(this.isNotQueryParser() &&
							this.testStrAndInc!"ubscription"(e))
					{
						if(this.isTokenStop()) {
							this.cur =
								Token(TokenType.subscription,
										this.line,
										this.column);
							return;
						}
					} else if(this.isNotQueryParser()
								&& this.testCharAndInc('c', e))
					{
						if(this.testStrAndInc!"alar"(e)) {
							if(this.isTokenStop()) {
								this.cur = Token(TokenType.scalar, this.line, this.column);
								return;
							}
						} else if(this.isNotQueryParser()
									&& this.testStrAndInc!"hema"(e))
						{
							if(this.isTokenStop()) {
								this.cur = Token(TokenType.schema, this.line, this.column);
								return;
							}
						}
					}
					goto default;
				case 'o':
					++this.stringPos;
					++this.column;
					++e;
					if(this.testCharAndInc('n', e)) {
						if(this.isTokenStop()) {
							this.cur = Token(TokenType.on_, this.line,
									this.column);
							return;
						}
					}
					goto default;
				case 'd':
					++this.stringPos;
					++this.column;
					++e;
					if(this.testStrAndInc!"irective"(e)) {
						if(this.isTokenStop()) {
							this.cur = Token(TokenType.directive,
									this.line, this.column);
							return;
						}
					}
					goto default;
				case 'e':
					++this.stringPos;
					++this.column;
					++e;
					if(this.testStrAndInc!"num"(e)) {
						if(this.isTokenStop()) {
							this.cur = Token(TokenType.enum_,
									this.line, this.column);
							return;
						}
					} else if(this.testStrAndInc!"xtend"(e)) {
						if(this.isTokenStop()) {
							this.cur = Token(TokenType.extend,
									this.line, this.column);
							return;
						}
					}
					goto default;
				case 'i':
					++this.stringPos;
					++this.column;
					++e;
					if(this.testCharAndInc('n', e)) {
						if(this.isNotQueryParser()
								&& this.testCharAndInc('p', e)
							)
						{
							if(this.testStrAndInc!"ut"(e)) {
								if(this.isTokenStop()) {
									this.cur = Token(TokenType.input,
											this.line, this.column);
									return;
								}
							}
						} else if(this.testStrAndInc!"terface"(e)) {
							if(this.isTokenStop()) {
								this.cur = Token(TokenType.interface_,
										this.line, this.column);
								return;
							}
						}
					} else if(this.testStrAndInc!"mplements"(e)) {
						if(this.isTokenStop()) {
							this.cur = Token(TokenType.implements,
									this.line, this.column);
							return;
						}
					}

					goto default;
				case 'f':
					++this.stringPos;
					++this.column;
					++e;
					if(this.testStrAndInc!"alse"(e)) {
						if(this.isTokenStop()) {
							this.cur = Token(TokenType.false_,
									this.line, this.column);
							return;
						}
					} else if(this.testStrAndInc!"ragment"(e)) {
						if(this.isTokenStop()) {
							this.cur =
								Token(TokenType.fragment,
										this.line,
										this.column);
							return;
						}
					}
					goto default;
				case 'q':
					++this.stringPos;
					++this.column;
					++e;
					if(this.testStrAndInc!"uery"(e)) {
						if(this.isTokenStop()) {
							this.cur = Token(TokenType.query,
									this.line, this.column);
							return;
						}
					}
					goto default;
				case 't':
					++this.stringPos;
					++this.column;
					++e;
					if(this.testStrAndInc!"rue"(e)) {
						if(this.isTokenStop()) {
							this.cur = Token(TokenType.true_,
									this.line, this.column);
							return;
						}
					} else if(this.isNotQueryParser()
							&& this.testStrAndInc!"ype"(e))
					{
						if(this.isTokenStop()) {
							this.cur = Token(TokenType.type,
									this.line, this.column);
							return;
						}
					}
					goto default;
				case 'n':
					++this.stringPos;
					++this.column;
					++e;
					if(this.testStrAndInc!"ull"(e)) {
						if(this.isTokenStop()) {
							this.cur = Token(TokenType.null_,
									this.line, this.column);
							return;
						}
					}
					goto default;
				case 'u':
					++this.stringPos;
					++this.column;
					++e;
					if(this.testStrAndInc!"nion"(e)) {
						if(this.isTokenStop()) {
							this.cur = Token(TokenType.union_,
									this.line, this.column);
							return;
						}
					}
					goto default;
				case '.':
					++this.stringPos;
					++this.column;
					++e;
					if(this.testStrAndInc!".."(e)) {
						if(this.isTokenStop()
								|| (this.stringPos < this.input.length
									&& isAlphaNum(this.input[this.stringPos])
									)
							)
						{
							this.cur = Token(TokenType.dots, this.line,
									this.column);
							return;
						}
					}
					throw new Exception(format(
							"failed to parse \"...\" at line %s column %s",
							this.line, this.column
						));
				case '-':
					++this.stringPos;
					++this.column;
					++e;
					goto case '0';
				case '+':
					++this.stringPos;
					++this.column;
					++e;
					goto case '0';
				case '0': .. case '9':
					do {
						++this.stringPos;
						++this.column;
						++e;
					} while(this.stringPos < this.input.length
							&& this.input[this.stringPos] >= '0'
							&& this.input[this.stringPos] <= '9');

					if(this.stringPos >= this.input.length
							|| this.input[this.stringPos] != '.')
					{
						this.cur = Token(TokenType.intValue, this.input[b ..
								e], this.line, this.column);
						return;
					} else if(this.stringPos < this.input.length
							&& this.input[this.stringPos] == '.')
					{
						do {
							++this.stringPos;
							++this.column;
							++e;
						} while(this.stringPos < this.input.length
								&& this.input[this.stringPos] >= '0'
								&& this.input[this.stringPos] <= '9');

						this.cur = Token(TokenType.floatValue, this.input[b ..
								e], this.line, this.column);
						return;
					}
					goto default;
				case '"':
					++this.stringPos;
					++this.column;
					++e;
					while(this.stringPos < this.input.length
							&& (this.input[this.stringPos] != '"'
								|| (this.input[this.stringPos] == '"'
									&& this.input[this.stringPos - 1U] == '\\')
						 		)
						)
					{
						++this.stringPos;
						++this.column;
						++e;
					}
					++this.stringPos;
					++this.column;
					this.cur = Token(TokenType.stringValue, this.input[b + 1
							.. e], this.line, this.column);
					break;
				default:
					while(!this.isTokenStop()) {
						//writefln("455 '%s'", this.input[this.stringPos]);
						++this.stringPos;
						++this.column;
						++e;
					}
					this.cur = Token(TokenType.name, this.input[b .. e],
							this.line, this.column
						);
					break;
			}
		}
	}*/

	/*bool testCharAndInc(const(char) c, ref size_t e) @safe {
		if(this.stringPos < this.input.length
				&& this.input[this.stringPos] == c)
		{
			++this.column;
			++this.stringPos;
			++e;
			return true;
		} else {
			return false;
		}
	}

	bool testStrAndInc(string s)(ref size_t e) @safe {
		for(size_t i = 0; i < s.length; ++i) {
			if(this.stringPos < this.input.length
					&& this.input[this.stringPos] == s[i])
			{
				++this.column;
				++this.stringPos;
				++e;
			} else {
				return false;
			}
		}
		return true;
	}*/

	@property bool empty() const @safe {
		return this.input.empty
			&& this.cur.type == TokenType.undefined;
	}

	Token front() @property @safe {
		return this.cur;
	}

	@property Token front() const @safe @nogc pure {
		return this.cur;
	}

	void popFront() @safe {
		this.buildToken();
	}

	string getRestOfInput() const @safe {
		return this.input;
	}
}
