'use strict';
const marked = require('marked');
const katex = require('katex');
const path = require('path');
const Hapi = require('@hapi/hapi');
const fs = require('fs');
const plantumlEncoder = require('plantuml-encoder');

let current_fn_key = '';
let global_indicator = -1;
const defaultMarkDownCss = '/styles/github-markdown.css';
const smpConfig = {
	css: defaultMarkDownCss,
};

const smp_links = {};
function generateRandomString(length) {
	let result = '';
	const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
	const charactersLength = characters.length;
	for (let i = 0; i < length; i++) {
		result += characters.charAt(Math.floor(Math.random() * charactersLength));
	}
	return result;
}

//katex version: https://cdn.jsdelivr.net/npm/katex@0.15.1/dist/katex.min.css
const getStylesheet = function (fn_key) {
	const stylesheet = `
  <link rel="stylesheet" href="${smpConfig.css}" type="text/css">
	<link rel="stylesheet" href="/styles/highlight-github.css" type="text/css">
	<link rel="stylesheet" href="/styles/smp.css" type="text/css">
  <link rel="stylesheet" href="/styles/katex.min.css">
  <script src="/diffdom/diffDOM.js"></script>
  <script>const myFnKey="${fn_key}";</script>

	
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    .markdown-body {
      box-sizing: border-box;
      min-width: 200px;
      max-width: 980px;
      margin: 0 auto;
      padding: 45px;
    }

    @media (max-width: 767px) {
      .markdown-body {
        padding: 15px;
      }
    }
    .ball {
      width: 0;
      height: 0;
      border-right: 1rem solid red;
      margin-left: 0.5rem;
    }

  </style>
`;

	return stylesheet.replace(/\n/g, '');
};

//insert this script into the html ONCE
const getSmoothScrollScript = function (fn_key, lnr, thisline, showIndicator = true) {
	thisline = thisline.replace(/`/g, '\\`');
	return `
  <script type="module">
import * as sxMxPx_x_M1e2r0mxaidJs from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
window.sxMxPx_x_M1e2r0mxaidJs = sxMxPx_x_M1e2r0mxaidJs.default;
let thisTs = 0;
let lastTs = -1;
let use_indicator=undefined;
function removeExistingBalls(){
    const ballElements = document.querySelectorAll(".ball");

    ballElements.forEach((element) => {
      element.classList.remove("ball");
    });
}

function setIndicator(linenr, lineText){
  let thisAnchor=null;
  let foundLineNr = -5;
  for(let i=linenr; i>=0; i--){
      thisAnchor = document.querySelector(\`.lucas_tkbp_\${i}\`);
      if(thisAnchor !==null){
        foundLineNr = i;
        break;
      }else{
}
  }
  if(thisAnchor !== null){
      removeExistingBalls();
      thisAnchor.classList.add("ball");
  }
  if(foundLineNr !== linenr && lineText.trim()  !==   ""){
    try{window.find(lineText)}catch(err){}
  }
}

function scrollOnly(linenr, lineText){
  linenr = linenr - 3;
  if (linenr < 1) linenr = 0;
  let thisAnchor=null;
  let foundLineNr = -3;
  for(let i=linenr; i>=0; i--){
      thisAnchor = document.querySelector(\`.scrollTo.lucas_tkbp_\${i}\`);
      if(thisAnchor !==null){
        foundLineNr = i;
        break;
      }
  }
  if(thisAnchor !== null){
      try{thisAnchor.scrollIntoView({ behavior: 'smooth', block: 'start' });}catch(err){ }
  }
}

function scrollToLine(linenr, lineText){
  if(use_indicator===undefined?${showIndicator}:use_indicator ) setIndicator(linenr, lineText);
  scrollOnly(linenr, lineText);
}

scrollToLine(${lnr}, \`${thisline}\`);



let fetchFailed = 0;
let intervalId=0;
const dd = new diffDOM.DiffDOM();
function fetchData() {
    let url = "http://127.0.0.1:3030/getupdate/${fn_key}/" + thisTs;
    lastTs = thisTs;
    fetch(url)
      .then((response) => {
        return response.json();
      })
      .then((data) => {
        if(data.use_indicator !== undefined)
        {
          if(use_indicator === true && data.use_indicator === false){
              removeExistingBalls();
          }
          use_indicator = data.use_indicator;
        }
        switch(data.code){
          case 'touched_all':
            const oldElement = document.querySelector(".markdown-body");
            const newElement = oldElement.cloneNode(false);

            newElement.innerHTML = data.html;

            const diff = dd.diff(oldElement, newElement);
            dd.apply(oldElement, diff);



            requestAnimationFrame(() => {
                        setTimeout(()=>{scrollToLine(data.linenr, data.thisline);}, 200);
            });
            break;
          case 'touched_line':
            scrollToLine(data.linenr, data.thisline);
            break;
          default:
        }
        if(data.ts) {thisTs = data.ts; }
          const mermaidElement = document.querySelector('.mermaid');
          if(mermaidElement){
            window.sxMxPx_x_M1e2r0mxaidJs.initialize({startOnLoad:false});
            window.sxMxPx_x_M1e2r0mxaidJs.run({
              querySelector: '.mermaid',
              suppressErrors: true,
            }).then(()=>{
            })
          }
      })
      .catch((error) => {
        fetchFailed += 1;
        if(fetchFailed > 200){
          try{clearInterval(intervalId);}catch(err){}
        }
      });
}
intervalId = setInterval(fetchData, 500);
</script>
  `.replace(/\n/g, '');
};

const inputString = 'The file is [[example.txt]], and this is [[example2]]';
const regex_wiki = /\[\[(.*?)\]\]/g;
const regex_snippet = /^\s*{(.+)}\s*$/;
const regex_link = /\[(.*)]\s*\((.+)\)/;

let string_stores = {};
let fn_stores = {};
let buf_session = {};
let serNumber = 0;

const logFile = 'smp_server_log.txt';

function logToFile(...msgs) {
	const timestamp = new Date().toISOString();
	let message = msgs.join(' ');
	const logMessage = `${timestamp} - ${message}\n`;

	fs.appendFile(logFile, logMessage, (_) => {});
}

// Usage:
const renderer = new marked.Renderer();

// Override the 'codespan' function to handle inline math
renderer.codespan = function (text) {
	if (text.startsWith('\\(') && text.endsWith('\\)')) {
		const latex = text.slice(2, -2);
		return katex.renderToString(latex, { throwOnError: false });
	}
	return `<code>${text}</code>`;
};

const hljs = require('highlight.js');
let hl = function (code, lang) {
	const language = hljs.getLanguage(lang) ? lang : 'plaintext';
	return hljs.highlight(code, { language }).value;
};

const imagelizedLang = ['plantuml', 'math'];

function renderMermaid(mermaidCode, lineNr) {
	let svg = '';

	// Render the Mermaid code to an SVG image using a callback function
	mermaid.render('diagram_' + lineNr, mermaidCode, (result) => {
		svg = result;
	});

	// Return the SVG image as a string
	return svg;
}

// Override the 'code' function to handle block-level math
// renderer.code = function (code, infostring) {
// 	if (infostring === 'math') {
// 		return katex.renderToString(code, { displayMode: true, throwOnError: false });
// 	}
// 	return `<pre><code class="hljs language-${infostring}">${hl(code, infostring)}</code></pre>`;
// };
renderer.code = function (code, infostring, lineNumber) {
	// return `<pre><code class="language-${infostring}">${code}</code></pre>`;
	if (infostring === 'math') {
		return katex.renderToString(code, { displayMode: true, throwOnError: false });
	} else if (infostring === 'plantuml') {
		const imageUrl = generatePlantUmlImageUrl(code);
		return `<img src="${imageUrl}"/>`;
	} else if (infostring === 'mermaid') {
		return `<span class="mermaid">${code}</span>`;
	}
	return `<pre><code class="hljs language-${infostring}">${hl(code, infostring)}</code></pre>`;
};

class CustomLexer extends marked.Lexer {
	constructor(options) {
		super(options);
	}

	lex(src) {
		const tokens = [];
		let lineNumber = 1;

		while (src) {
			const nextToken = super.token(src, true);
			if (nextToken) {
				src = src.slice(nextToken.raw.length);

				if (nextToken.type === 'code') {
					nextToken.lineNumber = lineNumber;
				}
				lineNumber += (nextToken.raw.match(/\n/g) || []).length;

				tokens.push(nextToken);
			} else {
				src = '';
			}
		}

		return tokens;
	}
}

marked.setOptions({
	renderer: renderer,
	Lexer: CustomLexer,
	highlight: function (code, lang) {
		const hljs = require('highlight.js');
		const language = hljs.getLanguage(lang) ? lang : 'plaintext';
		return hljs.highlight(code, { language }).value;
	},
	langPrefix: 'hljs language-', // highlight.js css expects a top-level 'hljs' class.
	pedantic: false,
	gfm: true,
	breaks: false,
	sanitize: false,
	smartypants: false,
	xhtml: false,
});

function getKeyByValue(obj, value) {
	for (const key in obj) {
		if (obj[key] === value) {
			return key;
		}
	}
}

function isValidUrl(string) {
	let url;

	try {
		url = new URL(string);
	} catch (_) {
		return false;
	}

	return url.protocol === 'http:' || url.protocol === 'https:';
}

function generatePlantUmlImageUrl(plantUmlSource) {
	const encodedPlantUml = plantumlEncoder.encode(plantUmlSource);
	const plantUmlServerUrl = 'http://www.plantuml.com/plantuml/img/';
	return plantUmlServerUrl + encodedPlantUml;
}
const indicator = function (lnr, scroll = true) {
	return `<span class="${scroll ? 'scrollto' : ''} lucas_tkbp_${lnr + 1}">&nbsp;</span>`;
};

const patchLine = (line, lnr, dir_of_current_md, patchLineNr = true) => {
	//Reference , don't touch

	if (line.match(/^\s*\[.+]:\s*.+$/)) {
		//Refen
		patchLineNr = false;
	} else if (line.match(/^\s*$/)) {
		//Patch bank line
		//Blank like, don't touch
		patchLineNr = patchLineNr;
		return '';
	} else if (line.match(regex_snippet)) {
		let m = line.match(regex_snippet);
		let snippetName = m[1].trim();
		function parse_snippet_content(snippet, level = 0) {
			//stop parse if level > 9
			if (level > 9) return null;
			if (!(smpConfig && smpConfig.snippets_folder)) {
				logToFile('smpConfig.snippets_folder is not defined');
				return null;
			}
			let fullPath = path.resolve(smpConfig.snippets_folder, snippet + '.md');
			if (fs.existsSync(fullPath)) {
				let content = fs.readFileSync(fullPath, 'utf8');
				let lines = content.split('\n');
				let foundChildSnippet = false;
				let retContentLines = [];
				for (let i = 0; i < lines.length; i++) {
					if (lines[i].match(regex_snippet)) {
						foundChildSnippet = true;
						let m = lines[i].match(regex_snippet);
						let childSnippetName = m[1].trim();
						retContentLines.push(parse_snippet_content(childSnippetName, level + 1) || lines[i]);
					} else {
						retContentLines.push(lines[i]);
					}
				}
				return retContentLines.join('\n') + '\n';
			} else {
				return null;
			}
		}
		if (snippetName) line = parse_snippet_content(snippetName, 0) || line;
	} else if (line.match(/\[\[.+]]/)) {
		//Patch WIKI link
		//Wiki link, a bit more complicated
		//I use this syntax heavily in Telekasten
		let outputString = line.replace(regex_wiki, (match, p1) => {
			let fullPath = path.resolve(dir_of_current_md, p1.match(/^.+\.(.+)$/) ? p1 : p1 + '.md');
			// const fullPath = path.resolve(p1);
			// const fileName = path.basename(p1);
			const fileExists = fs.existsSync(fullPath);
			if (fileExists) {
				let mySer = serNumber;
				let myKey = getKeyByValue(fn_stores, fullPath);
				if (!myKey) {
					myKey = `fn_${mySer}`;
					serNumber = serNumber + 1;
					fn_stores[myKey] = fullPath;
				}
				//Give it 'zettel' class, so the display style of zettel can be easily customized later
				return `<span class="zettel"><a href="/zettel/${myKey}">${p1}</a></span>`;
			} else {
				//also highlight missing zettel file
				return `<span class="notfound">${p1}</span>`;
			}
		});
		// logToFile('convert ' + line + ' to ' + outputString);
		line = outputString;
	} else if (line.match(regex_link)) {
		//Patch local MD link
		//如果是 [name](link) 方式
		let outputString = line.replace(regex_link, (match, p1, p2) => {
			if (isValidUrl(p2)) {
				//if link is valid url, return normal Markdown link
				return `[${p1}](${p2})`;
			} else if (p2.startsWith('#')) {
				return `[${p1}](${p2})`;
			} else {
				//if a wiki style link to a local file
				//convert it to SMP_LINK handler
				let fn = path.resolve(dir_of_current_md, p2);
				let linkId = generateRandomString(20);
				smp_links[linkId] = fn;
				return `[${p1}](/SMP_LINK/${linkId})`;
			}
		});
		// logToFile(`Replace [${line}] to [${outputString}]`);
		line = outputString;
	}
	return patchLineNr ? `${line}${indicator(lnr)}` : line;
};

const init = async () => {
	const server = Hapi.server({
		port: 3030,
		host: '127.0.0.1',
		routes: {
			files: {
				relativeTo: path.join(__dirname, 'public'),
			},
		},
	});
	await server.register(require('@hapi/inert'));

	server.route({
		method: 'GET',
		path: '/{param*}',
		handler: {
			directory: {
				path: '.',
				redirectToSlash: true,
			},
		},
	});

	server.route({
		method: 'GET',
		path: '/',
		handler: (_, h) => {
			return 'Hello Simple Markdown Preview!';
		},
	});

	server.r;
	server.route({
		method: 'POST',
		path: '/indicator',
		handler: (request, _) => {
			let payload = request.payload;
			logToFile(JSON.stringify(payload));
			global_indicator = Number(payload.indicator);
		},
	});
	server.route({
		method: 'GET',
		path: '/preview/{fn_key}',
		handler: (request, h) => {
			let fn_key = request.params.fn_key;
			let md_cache = string_stores[fn_key];
			if (md_cache) {
				const data = marked.parse(md_cache.string);
				const resp_html =
					'<head>' +
					getStylesheet(fn_key) +
					'</head>' +
					indicator(-1) +
					'<article class="markdown-body">\n' +
					data +
					'</article>' +
					getSmoothScrollScript(
						fn_key,
						md_cache.pos[0],
						md_cache.thisline.trim(),
						global_indicator < 0 ? smpConfig.show_indicator : global_indicator === 0 ? false : true,
					) +
					`<center><br/><br/>generated by <a href="https://github.com/cnshsliu/smp.nvim">smp.nvim</a>, created by <a href="https://www.buymeacoffee.com/liukehong">LiuKeHong</a> </center>`;
				return h.response(resp_html);
			} else {
				return h.response('Not found');
			}
		},
	});

	function replacePath(path, newFolder) {
		let newPath = path.replace(/\/SMP_MD_HOME\//, newFolder);

		return newPath;
	}
	server.route({
		method: 'GET',
		path: '/SMP_LINK/{fn}',
		handler: (request, h) => {
			let fn = smp_links[request.params.fn];
			if (fn.indexOf('/SMP_MD_HOME') >= 0) {
				fn = replacePath(fn, smpConfig.home);
			}
			return h.file(fn, { confine: false });
		},
	});
	server.route({
		method: 'GET',
		//this pattern pattern is generated by marked from a [[wikilink]]
		path: '/SMP_MD_HOME/assets/{fn}',
		handler: (request, h) => {
			let fn = path.join(smpConfig.home, 'assets', request.params.fn);
			logToFile('get ' + fn);
			return h.file(fn, { confine: false });
		},
	});
	server.route({
		method: 'GET',
		path: '/get_fn_key',
		handler: (_, h) => {
			return h.response({ fn_key: current_fn_key });
		},
	});
	server.route({
		method: 'GET',
		path: '/getupdate/{fn_key}/{ts}',
		handler: (request, h) => {
			let { fn_key, ts } = request.params;
			function getResponse() {
				let use_indicator =
					global_indicator < 0 ? smpConfig.show_indicator : global_indicator === 0 ? false : true;
				let md_cache = string_stores[fn_key];
				if (md_cache) {
					if (md_cache.ts !== Number(ts)) {
						if (md_cache.touched[0]) {
							const data = marked.parse(md_cache.string);
							return h.response({
								code: 'touched_all',
								html: data,
								linenr: md_cache.pos[0],
								thisline: md_cache.thisline.trim(),
								ts: md_cache.ts,
								use_indicator: use_indicator,
							});
						} else if (md_cache.touched[1]) {
							return h.response({
								code: 'touched_line',
								linenr: md_cache.pos[0],
								thisline: md_cache.thisline.trim(),
								ts: md_cache.ts,
								use_indicator: use_indicator,
							});
						} else {
							return h.response({
								code: 'touched_none',
								ts: md_cache.ts,
								use_indicator: use_indicator,
							});
						}
					} else {
						return h.response({ code: 'notouch' });
					}
				} else {
					return h.response({ code: 'nocache' });
				}
			}

			return getResponse();
		},
	});
	server.route({
		method: 'GET',
		//this path pattern is generated from Wiki Link: [[myKey]]
		path: '/zettel/{myKey}',
		handler: (request, h) => {
			// Compile
			let fn = fn_stores[request.params.myKey];
			logToFile('zettel: ' + fn);
			const fileExists = fs.existsSync(fn);
			if (fileExists) {
				let dir_of_current_md = path.dirname(fn);
				let md = fs.readFileSync(fn, 'utf8');
				md = patchLine(md, 0, dir_of_current_md, false);
				const data = marked.parse(md);

				return h.response(
					getStylesheet() + '<article class="markdown-body">' + data + '</article>',
				);
			} else {
				return h.response(
					'Not found. <br/>You may edit your MD normally, and refresh this page later.',
				);
			}
		},
	});
	server.route({
		method: 'GET',
		//this path pattern is within previous output, which is a generate by marked from [name](./assets/....)
		path: '/zettel/{path}/{any*}',
		handler: (request, h) => {
			let fn = path.join(smpConfig.home, request.params.path, request.params.any);
			return h.file(fn, { confine: false });
		},
	});
	server.route({
		method: 'POST',
		path: '/config',
		handler: (request, h) => {
			let payload = request.payload;
			if (payload.cssfile) {
				if (fs.existsSync(payload.cssfile)) {
					smpConfig.css = `http://127.0.0.1:3030/SMP_LINK/${Buffer.from(payload.cssfile).toString(
						'base64',
					)}`;
				} else {
					smpConfig.css = defaultMarkDownCss;
				}
			}
			const keys = ['snippets_folder', 'home', 'show_indicator'];
			for (let i = 0; i < keys.length; i++) {
				const key = keys[i];
				smpConfig[key] = payload[key];
			}
			if (smpConfig.home && smpConfig.home.endsWith('/') === false) {
				smpConfig.home += '/';
			}
			logToFile('config updated: ' + JSON.stringify(smpConfig, null, 2));
			return h.response('config updated');
		},
	});
	server.route({
		method: 'POST',
		path: '/update',
		handler: (request, h) => {
			let payload = request.payload;
			let fn = payload.fn;
			let codeStart = -1;
			let codeEnd = -1;
			let patched = [];
			let pure = [];
			let lines = payload.lines;
			let fn_key = payload.fn_key;
			if (!fn_key || !fn) {
				payload.lines.splice(1, payload.lines.length - 1, '...');
				logToFile('fn_key is undefined, bypass update ' + JSON.stringify(payload));
				return h.response('fn_key is undefined, bypass update');
			}
			let dir_of_current_md = path.dirname(fn);
			let codeLang = '';
			if (lines.length > 0 && lines[0] !== 'NO_CHANGE') {
				//update content
				for (let i = 0; i < lines.length; i++) {
					let x = lines[i];
					pure.push(x);
					patched.push(patchLine(lines[i], i, dir_of_current_md, true));

					if (x.match(/^\s*`/)) {
						//a code block start
						if (codeStart < 0) {
							codeStart = i;
							let match = x.match(/```(\w*)/);
							if (match) {
								codeLang = match[1];
							} else {
								codeLang = '';
							}
						} else codeEnd = i;
						if (codeEnd > 0) {
							for (let j = codeStart; j <= codeEnd; j++) {
								patched[j] = pure[j];
							}
							if (imagelizedLang.indexOf(codeLang) >= 0) {
								//for imagelized text, no auto scroll
								//Befote the code start
								//insert a indicator after a new line mark
								patched[codeStart] =
									'&nbsp;' + indicator(codeStart, true) + '\n' + patched[codeStart];

								//For those markdown lines which will be converted
								//into a picture, we insert patch, only used for highlight
								//without scroll to it,
								//Why do we need no-scroll-to location? because if you are
								//editing a imagelizable mardown section which have many lines
								//or when you move cursor within this area
								//the browser will jump to this location
								//make your editing experience unstable.
								patched[codeEnd] += '\n&nbsp;' + indicator(codeStart + 1, false);
							}
							codeStart = -1;
							codeEnd = -1;
							codeLang = '';
						}
					}
				}
				let md_string = patched.join('\n');
				// logToFile(
				// 	'Reeived ... ' +
				// 		payload.lines.length +
				// 		' lines, pos:' +
				// 		payload.pos +
				// 		', fn:' +
				// 		payload.fn,
				// );
				// fs.writeFile('/Users/lucas/tmp/buf1.md', md_string, 'utf8', (err) => {
				// 	if (err) {
				// 		console.error('Error writing file:', err);
				// 	} else {
				// 		console.log('File written successfully');
				// 	}
				// });
				// logToFile('Write store for bufnr ' + payload.bufnr);
				string_stores[fn_key] = {
					string: md_string,
					pos: payload.pos,
					fn: payload.fn,
					fn_key: payload.fn_key,
					thisline: payload.thisline,
					touched: [true, true], //touch content and linenr
					ts: new Date().getTime(),
				};
				current_fn_key = fn_key;
				logToFile(
					'Update content:\t' + current_fn_key + ' , pos to :' + JSON.stringify(payload.pos),
				);
				//TODO: must update without defer
			} else {
				current_fn_key = fn_key;
				logToFile(
					'Update position:\t' + current_fn_key + ' , pos to: ' + JSON.stringify(payload.pos),
				);
				let store = string_stores[fn_key];
				if (store) {
					string_stores[fn_key] = {
						string: store.string,
						pos: payload.pos,
						fn: payload.fn,
						fn_key: fn_key,
						thisline: payload.thisline,
						touched: [false, true], //touch linenr only
						ts: new Date().getTime(),
					};
				}
			}
			let ret = `Bufnr: ${payload.bufnr}, Pos: ${payload.pos}, Stores: ${
				Object.keys(string_stores).length
			} `;
			const response = h.response(ret);
			response.header('Connection', 'keep-alive');
			return response;
		},
	});
	server.route({
		method: 'POST',
		path: '/stop',
		handler: (request, h) => {
			logToFile('Receive stop request, stop now!!!');
			setTimeout(() => {
				process.exit(1);
			}, 1000);
			return 'Stopped';
		},
	});

	await server.start();
	logToFile('Server running on ' + server.info.uri);
};

process.on('unhandledRejection', (err) => {
	console.log(err);
	process.exit(1);
});

init();
