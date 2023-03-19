const hashtag_re = '(^|\\s|\'|")#[a-zA-ZÀ-ÿ\\p{Script=Han}]+[a-zA-ZÀ-ÿ0-9/\\-_\\p{Script=Han}]*';
// -- PCRE hashtag allows to remove the hex color codes from hastags
const hashtag_re_pcre =
	'(^|\\s|\'|")((?!(#[a-fA-F0-9]{3})(\\W|$)|(#[a-fA-F0-9]{6})(\\W|$))' +
	'#[a-zA-ZÀ-ÿ\\p{Script=Han}]+[a-zA-ZÀ-ÿ0-9/\\-_\\p{Script=Han}]*)';
const colon_re = '(^|\\s):[a-zA-ZÀ-ÿ\\p{Script=Han}]+[a-zA-ZÀ-ÿ0-9/\\-_\\p{Script=Han}]*:';
const yaml_re =
	'(^|\\s)tags:\\s*\\[\\s*([a-zA-ZÀ-ÿ\\p{Script=Han}]+[a-zA-ZÀ-ÿ0-9/\\-_\\p{Script=Han}]*(,\\s*)*)*\\s*]';

const M = {};
function command_find_all_tags(opts) {
	opts = opts || {};
	opts.cwd = opts.cwd || '.';
	opts.templateDir = opts.templateDir || '';
	opts.rg_pcre = opts.rg_pcre || false;

	// -- do not list tags in the template directory
	let globArg = '';
	if (opts.templateDir != '') {
		globArg = '--glob=!' + '**/' + opts.templateDir + '/*.md';
	}

	let re = hashtag_re;

	if (opts.tag_notation == ':tag:') {
		re = colon_re;
	}

	if (opts.tag_notation == 'yaml-bare') {
		re = yaml_re;
	}

	let rg_args = ['--vimgrep', globArg, '-o', re, '--', opts.this_file || opts.cwd];

	// -- PCRE engine allows to remove hex color codes from #hastags
	if (opts.rg_pcre && re == hashtag_re) {
		re = hashtag_re_pcre;

		rg_args = ['--vimgrep', '--pcre2', globArg, '-o', re, '--', opts.this_file || opts.cwd];
	}

	return 'rg', rg_args;
}

M.command_find_all_tags = command_find_all_tags;
module.exports = M;
