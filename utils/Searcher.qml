import Quickshell

import "scripts/fzf.js" as Fzf
import "scripts/fuzzysort.js" as Fuzzy
import QtQuick

Singleton {
    required property list<QtObject> list
    property string key: "name"
    property bool useFuzzy: false
    property var extraOpts: ({})

    // Extra stuff for fuzzy
    property list<string> keys: [key]
    property list<real> weights: [1]

    readonly property var fzf: useFuzzy ? [] : new Fzf.Finder(list, Object.assign({
        selector
    }, extraOpts))
    readonly property list<var> fuzzyPrepped: useFuzzy ? list.map(e => {
        const obj = {
            _item: e
        };
        for (const k of keys)
            obj[k] = Fuzzy.prepare(e[k]);
        return obj;
    }) : []

    function transformSearch(search: string): string {
        return search;
    }

    function selector(item: var): string {
        // Only for fzf
        return item[key];
    }

    // Subclass can set this to a function(item) that returns extra score (e.g. click frequency * weight)
    property var extraScore: function(item) { return 0; }

    function query(search: string): list<var> {
        search = transformSearch(search);
        if (!search)
            return [...list].sort((a, b) => extraScore(b) - extraScore(a));

        if (useFuzzy)
            return Fuzzy.go(search, fuzzyPrepped, Object.assign({
                all: true,
                keys,
                scoreFn: r => weights.reduce((a, w, i) => a + r[i].score * w, 0) + extraScore(r.obj._item)
            }, extraOpts)).map(r => r.obj._item);

        return fzf.find(search).sort((a, b) => {
            const scoreA = a.score + extraScore(a.item);
            const scoreB = b.score + extraScore(b.item);
            if (scoreA === scoreB)
                return selector(a.item).trim().length - selector(b.item).trim().length;
            return scoreB - scoreA;
        }).map(r => r.item);
    }
}
