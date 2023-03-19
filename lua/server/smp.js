'use strict';

const marked = require('marked');
const path = require('path');
const Hapi = require('@hapi/hapi');
const fs = require('fs');
const BookUtils = require('./bookutils');

const stylesheet = `
  <link rel="stylesheet" href="/styles/github-markdown.css" type="text/css">
	<link rel="stylesheet" href="/styles/highlight-github.css" type="text/css">
	<link rel="stylesheet" href="/styles/smp.css" type="text/css">
	
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    #markdown-body {
      box-sizing: border-box;
      min-width: 200px;
      max-width: 980px;
      margin: 0 auto;
      padding: 45px;
    }

    @media (max-width: 767px) {
      #markdown-body {
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

function generateUUIDv4() {
	return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
		const r = (Math.random() * 16) | 0;
		const v = c === 'x' ? r : (r & 0x3) | 0x8;
		return v.toString(16);
	});
}

const getSmoothScrollScript = function (bufnr, lnr, thisline) {
	thisline = thisline.replace(/`/g, '\\`');
	return `
<script type="text/javascript">
let thisTs = 0;
let lastTs = -1;
function removeExistingBalls(){
    const ballElements = document.querySelectorAll(".ball");

    ballElements.forEach((element) => {
      element.classList.remove("ball");
    });
}

function setIndicator(linenr, lineText){
console.log('setIndicator', linenr, lineText);
  let thisAnchor=null;
  let foundLineNr = linenr;
  for(let i=linenr; i>=1; i--){
      thisAnchor = document.querySelector('a[name="lucas_tkbp_' + i + '"]');
      if(thisAnchor !==null){
        foundLineNr = i;
        break;
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
console.log('scrollOnly', linenr, lineText);
  linenr = linenr - 3;
  if (linenr < 1) linenr = 1;
  let thisAnchor=null;
  let foundLineNr = linenr;
  for(let i=linenr; i>=1; i--){
      thisAnchor = document.querySelector('a[name="lucas_tkbp_' + i + '"]');
      if(thisAnchor !==null){
        foundLineNr = i;
        break;
      }
  }
  if(thisAnchor !== null){
      try{thisAnchor.scrollIntoView({ behavior: 'smooth', block: 'start' });}catch(err){}
  }
}

function scrollToLine(linenr, lineText){
console.log('scrollToLine', linenr, lineText);
  setIndicator(linenr, lineText);
  scrollOnly(linenr, lineText);
}

scrollToLine(${lnr}, \`${thisline}\`);



let fetchFailed = 0;
let intervalId=0;
function fetchData() {
    let url = "http://127.0.0.1:3030/getupdate/${bufnr}/" + thisTs;
    lastTs = thisTs;
    fetch(url)
      .then((response) => {
        return response.json();
      })
      .then((data) => {
        switch(data.code){
          case 'touched_all':
            document.querySelector("#markdown-body").innerHTML = data.html;
            scrollToLine(data.linenr, data.thisline);
            break;
          case 'touched_line':
            scrollToLine(data.linenr, data.thisline);
            break;
          default:
        }
        if(data.ts) {thisTs = data.ts; }
      })
      .catch((error) => {
        // console.error("There was a problem with the fetch operation:", error);
        fetchFailed += 1;
        if(fetchFailed > 10){
          try{clearInterval(intervalId);}catch(err){}
        }
      });
}
intervalId = setInterval(fetchData, 300);
</script>
  `;
};

const inputString = 'The file is [[example.txt]], and this is [[example2]]';
const regex_wiki = /\[\[(.*?)\]\]/g;
const regex_link = /\[(.*)]\s*\((.+)\)/;

let string_stores = {};
let fn_stores = {};
let buf_session = {};
let serNumber = 0;

const logFile = 'smp_server_log.txt';

function logToFile(message) {
	const timestamp = new Date().toISOString();
	const logMessage = `${timestamp} - ${message}\n`;

	fs.appendFile(logFile, logMessage, (err) => {
		if (err) {
			console.error('Error writing log message:', err);
			// } else {
			// 	console.log('Log message written:', message);
		}
	});
}

// Usage:
logToFile('This is a log message.');
marked.setOptions({
	renderer: new marked.Renderer(),
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

const patchLine = (line, lnr, mydir, patchLineNr = true) => {
	//Reference , dont' touch
	logToFile('patchline:', line);
	if (line.match(/^\s*\[.+]:\s*.+$/)) {
		//Refen
		return line;
	} else if (line.match(/^\s*$/)) {
		//Blank like, dont' touch
		return line;
	} else if (line.match(/\[\[.+]]/)) {
		//Wiki link, a bit more complicated
		//I use this syntax heavily in Telekasten
		let outputString = line.replace(regex_wiki, (match, p1) => {
			let fullPath = path.resolve(mydir, p1.match(/^.+\.(.+)$/) ? p1 : p1 + '.md');
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
				return `<span class="zettel"><a href="/zettel/${myKey}">${p1}</a></spa>`;
			} else {
				//also highlight missing zettel file
				return `<span class="notfound">${p1}</span>`;
			}
		});
		line = outputString;
	} else if (line.match(regex_link)) {
		let outputString = line.replace(regex_link, (match, p1, p2) => {
			if (isValidUrl(p2)) {
				return `[${p1}](${p2})`;
			} else {
				let fn = path.resolve(mydir, p2);
				return `[${p1}](/SMP_LINK/${Buffer.from(fn).toString('base64')})`;
			}
		});
		logToFile(`Replace [${line}] to [${outputString}]`);
		line = outputString;
	}
	return patchLineNr
		? `${line}<a href="lucas_tkbp_${lnr + 1}" name="lucas_tkbp_${
				lnr + 1
		  }"><span class="lucas_tkbp_${lnr + 1}"></span></a>`
		: line;
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
		handler: (request, h) => {
			return 'Hello Simple Markdown Preview!';
		},
	});
	server.route({
		method: 'GET',
		path: '/preview/{bufnr}',
		handler: (request, h) => {
			// Compile
			let md_cache = string_stores['bufnr_' + request.params.bufnr];
			if (md_cache) {
				logToFile('MD preview for bufnr ' + request.params.bufnr);
				const data = marked.parse(md_cache.string);

				return h.response(
					stylesheet +
						'<article id="markdown-body">' +
						data +
						'</article>' +
						getSmoothScrollScript(request.params.bufnr, md_cache.pos[0], md_cache.thisline.trim()),
				);
			} else {
				logToFile('MD preview for bufnr ' + request.params.bufnr + ' not found');
				return h.response('Not found');
			}
		},
	});
	server.route({
		method: 'GET',
		path: '/SMP_LINK/{fn}',
		handler: (request, h) => {
			let fn = Buffer.from(request.params.fn, 'base64').toString();
			logToFile('send image: ' + fn);
			return h.file(fn, { confine: false });
		},
	});
	server.route({
		method: 'GET',
		path: '/getupdate/{bufnr}/{ts}',
		handler: (request, h) => {
			let { bufnr, ts } = request.params;
			function getResponse() {
				let md_cache = string_stores['bufnr_' + bufnr];
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
							});
						} else if (md_cache.touched[1]) {
							return h.response({
								code: 'touched_line',
								linenr: md_cache.pos[0],
								thisline: md_cache.thisline.trim(),
								ts: md_cache.ts,
							});
						} else {
							return h.response({
								code: 'touched_none',
								ts: md_cache.ts,
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
		path: '/zettel/{myKey}',
		handler: (request, h) => {
			// Compile
			let fn = fn_stores[request.params.myKey];
			const fileExists = fs.existsSync(fn);
			if (fileExists) {
				logToFile('Zettel file sent:' + fn);
				let mydir = path.dirname(fn);
				let md = fs.readFileSync(fn, 'utf8');
				md = patchLine(md, 0, mydir, false);
				const data = marked.parse(md);

				return h.response(stylesheet + '<article class="markdown-body">' + data + '</article>');
			} else {
				logToFile('Zettel not found: ' + fn);
				return h.response('Not found');
			}
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
			if (!fn) {
				payload.lines.splice(1, payload.lines.length - 1, '...');
				logToFile('Filename is undefined, bypass update ' + JSON.stringify(payload));
				return h.response('Filename is undefined, bypass update');
			}
			let mydir = path.dirname(fn);
			if (lines.length > 0 && lines[0] !== 'NO_CHANGE') {
				//update content
				for (let i = 0; i < lines.length; i++) {
					let x = lines[i];
					pure.push(x);
					patched.push(patchLine(lines[i], i, mydir, true));

					if (x.match(/^\s*`/)) {
						if (codeStart < 0) codeStart = i;
						else codeEnd = i;
						if (codeEnd > 0) {
							for (let j = codeStart; j <= codeEnd; j++) {
								patched[j] = pure[j];
							}
							codeStart = -1;
							codeEnd = -1;
						}
					}
				}
				let md_string = patched.join('\n');
				logToFile(
					'Reeived ... ' +
						payload.lines.length +
						' lines, pos:' +
						payload.pos +
						', fn:' +
						payload.fn,
				);
				// fs.writeFile('/Users/lucas/tmp/buf1.md', md_string, 'utf8', (err) => {
				// 	if (err) {
				// 		console.error('Error writing file:', err);
				// 	} else {
				// 		console.log('File written successfully');
				// 	}
				// });
				logToFile('Write store for bufnr ' + payload.bufnr);
				string_stores['bufnr_' + payload.bufnr] = {
					string: md_string,
					pos: payload.pos,
					fn: payload.fn,
					thisline: payload.thisline,
					touched: [true, true], //touch content and linenr
					ts: new Date().getTime(),
				};
			} else {
				logToFile('Update buf ' + payload.bufnr + ' pos to ' + JSON.stringify(payload.pos));
				let store = string_stores['bufnr_' + payload.bufnr];
				if (store) {
					string_stores['bufnr_' + payload.bufnr] = {
						string: store.string,
						pos: payload.pos,
						fn: payload.fn,
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
