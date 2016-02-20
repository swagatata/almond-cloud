// -*- mode: js; indent-tabs-mode: nil; js-basic-offset: 4 -*-
//
// This file is part of ThingEngine
//
// Copyright 2015 Giovanni Campagna <gcampagn@cs.stanford.edu>
//
// See COPYING for details

const Q = require('q');
const express = require('express');
const passport = require('passport');

const db = require('../util/db');
const model = require('../model/user');
const user = require('../util/user');
const EngineManager = require('../enginemanager');
const AssistantDispatcher = require('../assistantdispatcher');

var router = express.Router();

router.get('/create', user.redirectLogIn, function(req, res, next) {
    if (req.query.class && ['online', 'physical'].indexOf(req.query.class) < 0) {
        res.status(404).render('error', { page_title: "ThingEngine - Error",
                                          message: "Invalid device class" });
        return;
    }

    var online = req.query.class === 'online';

    res.render('devices_create', { page_title: 'ThingEngine - configure device',
                                   csrfToken: req.csrfToken(),
                                   developerKey: req.user.developer_key,
                                   onlineAccounts: online,
                                   ownTier: 'cloud',
                                 });
});

router.post('/create', user.requireLogIn, function(req, res, next) {
    if (req.query.class && ['online', 'physical'].indexOf(req.query.class) < 0) {
        res.status(404).render('error', { page_title: "ThingEngine - Error",
                                          message: "Invalid device class" });
        return;
    }

    EngineManager.get().getEngine(req.user.id).then(function(engine) {
        var devices = engine.devices;

        if (typeof req.body['kind'] !== 'string' ||
            req.body['kind'].length == 0)
            throw new Error("You must choose one kind of device");

        delete req.body['_csrf'];
        return devices.loadOneDevice(req.body, true);
    }).then(function() {
        if (req.session['device-redirect-to']) {
            res.redirect(303, req.session['device-redirect-to']);
            delete req.session['device-redirect-to'];
        } else {
            res.redirect(303, '/apps');
        }
    }).catch(function(e) {
        res.status(400).render('error', { page_title: "ThingEngine - Error",
                                          message: e.message });
    }).done();
});

router.post('/delete', user.requireLogIn, function(req, res, next) {
    if (req.query.class && ['online', 'physical'].indexOf(req.query.class) < 0) {
        res.status(404).render('error', { page_title: "ThingEngine - Error",
                                          message: "Invalid device class" });
        return;
    }

    EngineManager.get().getEngine(req.user.id).then(function(engine) {
        var id = req.body.id;
        if (!engine.devices.hasDevice(id)) {
            res.status(404).render('error', { page_title: "ThingEngine - Error",
                                              message: "Not found." });
            return false;
        }

        return engine.devices.getDevice(id).then(function(device) {
            return engine.devices.removeDevice(device);
        }).then(function() {
            return true;
        });
    }).then(function(ok) {
        if (!ok)
            return;
        if (req.session['device-redirect-to']) {
            res.redirect(303, req.session['device-redirect-to']);
            delete req.session['device-redirect-to'];
        } else {
            res.redirect(303, '/apps');
        }
    }).catch(function(e) {
        res.status(400).render('error', { page_title: "ThingEngine - Error",
                                          message: e.message });
    }).done();
});

// special case google because we have login with google
router.get('/oauth2/com.google', user.redirectLogIn, function(req, res, next) {
    req.session.redirect_to = '/apps';
    next();
}, passport.authorize('google', {
    scope: 'openid profile email' +
        ' https://www.googleapis.com/auth/fitness.activity.read' +
        ' https://www.googleapis.com/auth/fitness.location.read' +
        ' https://www.googleapis.com/auth/fitness.body.read',
    failureRedirect: '/apps',
    successRedirect: '/apps'
}));

// special case facebook because we have login with facebook
router.get('/oauth2/com.facebook', user.redirectLogIn, function(req, res, next) {
    req.session.redirect_to = '/apps';
    next();
}, passport.authorize('facebook', {
    scope: 'public_profile email',
    failureRedirect: '/apps',
    successRedirect: '/apps'
}));

router.get('/oauth2/:kind', user.redirectLogIn, function(req, res, next) {
    var kind = req.params.kind;

    EngineManager.get().getEngine(req.user.id).then(function(engine) {
        return engine.devices.factory;
    }).then(function(devFactory) {
        return devFactory.runOAuth2(kind, null);
    }).then(function(result) {
        if (result !== null) {
            var redirect = result[0];
            var session = result[1];
            for (var key in session)
                req.session[key] = session[key];
            res.redirect(303, redirect);
        } else {
            res.redirect(303, '/apps');
        }
    }).catch(function(e) {
        res.status(400).render('error', { page_title: "ThingEngine - Error",
                                          message: e.message });
    }).done();
});

// special case omlet to create the assistant right away
router.get('/oauth2/callback/org.thingpedia.builtin.omlet', user.redirectLogIn, function(req, res, next) {
    var kind = req.params.kind;

    EngineManager.get().getEngine(req.user.id).then(function(engine) {
        return engine.devices.factory.then(function(devFactory) {
            var saneReq = {
                httpVersion: req.httpVersion,
                url: req.url,
                headers: req.headers,
                rawHeaders: req.rawHeaders,
                method: req.method,
                query: req.query,
                body: req.body,
                session: req.session,
            };
            return devFactory.runOAuth2('org.thingpedia.builtin.omlet', saneReq);
        }).then(function() {
            return engine.messaging.getOwnId();
        }).then(function(ownId) {
            return engine.messaging.getAccountById(ownId);
        }).then(function(account) {
            return AssistantDispatcher.get().createFeedForEngine(req.user.id, engine, account);
        });
    }).then(function(feedId) {
        return db.withTransaction(function(dbClient) {
            return model.update(dbClient, req.user.id, { assistant_feed_id: feedId });
        });
    }).then(function() {
        if (req.session['device-redirect-to']) {
            res.redirect(303, req.session['device-redirect-to']);
            delete req.session['device-redirect-to'];
        } else {
            res.redirect(303, '/apps');
        }
    }).catch(function(e) {
        console.log(e.stack);
        res.status(400).render('error', { page_title: "ThingEngine - Error",
                                          message: e.message });
    }).done();
});

router.get('/oauth2/callback/:kind', user.redirectLogIn, function(req, res, next) {
    var kind = req.params.kind;

    EngineManager.get().getEngine(req.user.id).then(function(engine) {
        return engine.devices.factory;
    }).then(function(devFactory) {
        var saneReq = {
            httpVersion: req.httpVersion,
            url: req.url,
            headers: req.headers,
            rawHeaders: req.rawHeaders,
            method: req.method,
            query: req.query,
            body: req.body,
            session: req.session,
        };
        return devFactory.runOAuth2(kind, saneReq);
    }).then(function() {
        if (req.session['device-redirect-to']) {
            res.redirect(303, req.session['device-redirect-to']);
            delete req.session['device-redirect-to'];
        } else {
            res.redirect(303, '/apps');
        }
    }).catch(function(e) {
        res.status(400).render('error', { page_title: "ThingEngine - Error",
                                          message: e.message });
    }).done();
});

module.exports = router;
