# Latin language lexicons

Profiles may set `lexiconAsset` to an asset under `assets/lexicons/`. The JSON
contains a `code` matching the profile and `words`, either a list of lowercase
words or a map of words to positive numeric weights. Two distinct words are
required for a language-ID result. Missing, invalid, empty, or mismatched files
are ignored; existing romanized lexicons, channel votes, and caption probes
remain available. Confidence is a heuristic based on matched weights, not a
calibrated probability.

To create a candidate from UTF-8 title or caption files, supply a stopword file
for the relevant corpus and review the result for language collisions and
source licensing before bundling it:

```
dart run tool/build_latin_lexicon.dart <code> <samples.txt> --stopwords <stopwords.txt> --min-length 3 --min-frequency 2 --limit 1000
```

The generator counts each word at most once per input line. Add the resulting
asset path to the corresponding language profile to enable it.
