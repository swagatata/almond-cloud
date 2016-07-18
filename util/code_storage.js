// -*- mode: js; indent-tabs-mode: nil; js-basic-offset: 4 -*-
//
// This file is part of ThingEngine
//
// Copyright 2015 Giovanni Campagna <gcampagn@cs.stanford.edu>
//
// See COPYING for details

const fs = require('fs');
const Q = require('q');

function safeMkdir(dir) {
    try {
        fs.mkdirSync(dir);
    } catch(e) {
        if (e.code !== 'EEXIST')
            throw e;
    }
}

module.exports = {
    storeIcon: function(blob, name) {
        safeMkdir('./icons');
        return Q.nfcall(fs.writeFile, './icons/' + name + '.png');
    },
    storeFile: function(blob, name, version) {
        safeMkdir('./code');
        return Q.nfcall(fs.writeFile, './code/' + name + '-v' + version + '.zip', blob);
    },
};
