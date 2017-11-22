# OggAlbumTagger

[OggAlbumTagger](https://github.com/Sigill/OggAlbumTagger) est un script Ruby qui permet de tagger de la musique au format Ogg Vorbis. Il fonctionne de façon interactive, propose de l'auto-complétion et de l'auto-suggestion, supporte les tags multi-valués ainsi que les pochettes d'album. Il est capable de gérer des albums complets, de renommer les fichiers à partir des tags, et permet de vérifier certaines bonnes pratiques concernant le contenu des tags.

## Pourquoi OggAlbumTagger ?

Je voulais un outil offrant un contrôle total des tags mais qui intègre certains automatismes permettant de tagger facilement des albums complets.

Malheureusement, j'ai n'ai pas trouvé d'outil d'édition de tags qui me satisfasse. En vrac :

* Difficile d'accéder à des tags non standards.
* Impossible/difficile d'associer plusieurs valeurs à un même tag.
* Pas de gestion des pochettes.
* Alignement inutile des tags numériques avec des zéros.
* Ne permet pas le renommage des fichiers à partir des tags.
* Difficile de tagger un album complet.
* …

## Comment ça fonctionne ?

```
$ ogg-album-tagger [options] files|directories
Options:
    -a, --album    Album mode, treat a single directory as an album.
    -v, --version  Display version information and exit.
    -h, --help     Print this help.
```
Ouvrez un ensemble de fichiers/dossiers avec OggAlbumTagger : `ogg-album-tagger 01.ogg 02.ogg 03.ogg` (si vous spécifiez des dossiers, OggAlbumTagger va les parcourir récursivement à la recherche de fichiers ogg).

Le mode album (au sens large, la distinction entre album, best-of et compilation sera faite plus tard) permet d'activer des vérifications liées à la cohérence des tags spécifiques à un album, mais aussi de renommer le dossier de l'album en même temps que les fichiers. Vous devez alors passer en paramètre un unique dossier.

OggAlbumTagger fonctionne de façon interactive, comme un terminal : vous disposez d'un ensemble de commandes pour visualiser et éditer des tags.

### Notes préliminaires

* OggAlbumTagger fonctionne comme la plupart des terminaux. Les commandes et arguments doivent être séparés par un espace. Si un argument contient des caractères spéciaux (apostrophe, guillemet, espace), vous devez soit les échapper à l'aide d'un `\`, soit encadrer l'argument d'apostrophe ou de guillemets.
* La touche `tab` permet de faire de l'auto-completion et de l'auto-suggestion.
* Les noms des tags ne sont pas sensibles à la casse, mais sont écrits en majuscule dans les fichiers.
* Chaque tag peut avoir plusieurs valeurs, mais afin de respecter certaines bonnes pratiques, OggalbumTagger peut vous en empêcher.
* OggAlbumTagger utilise l'UTF-8 (mais pour l'instant, je ne sais pas ce qui se passe si le terminal utilise un autre encodage).

### Commandes disponibles

__`ls`__ : liste les fichiers en cours d'édition.

```
> ls
*    1: Queen - 01 - Bohemian Rapsody.ogg
*    2: Queen - 02 - Another One Bites The Dust.ogg
*    3: Queen - 03 - Killer Queen.ogg
...
```
Les étoiles en début de ligne indiquent les fichiers sélectionnés (se référer à la commande `select` pour plus de détails).

__`move <from_index> <to_index>`__: Déplace le fichier de position `from_index` à la position `to_index`. Si N fichiers ont été charges, alors `from_index` doit être dans l'intervalle [1; N] et `to_index` dans l'intervalle [1; N+1].

__`select arg1 [arg2…]`__ : permet de sélectionner un sous-ensemble de fichiers auxquels les commande d'édition. Vous avez à votre disposition les sélecteurs suivants :

* `all` : sélectionne tous les fichiers
* `i` : sélectionne le fichier à l'index `i` de la liste.
* `i-j` : sélectionne les fichiers de l'index `i` à l'index `j` de la liste.

Les sélecteurs à base d'index peuvent être préfixés d'un `+` ou d'un `-` afin d'ajouter ou de retirer des éléments à la sélection actuelle (ex. `-3` ou `+10-20`).

Il est également possible d'appliquer des sélecteurs à une unique commande en préfixant celle-ci (ex. `3-5 show`).

__`show`__ : sans argument, permet de visualiser les tags. `show xxx` permet de limiter la visualisation au tag `xxx`.

__`set <tag> value1 [value2…]`__ : tag chaque fichier avec chaque valeur. Les éventuelles valeurs précédentes de ce tag sont supprimées. Si le tag est `metadata_block_picture` (ou bien son alias `picture`), vous devez passer en argument le chemin d'un fichier jpeg ou png et optionnellement une description. Pour l'instant, seules les images de type "front cover" sont supportées.

__`add <tag> value1 [value2…]`__ : comme `set`, mais ne supprime pas les valeurs précédentes.

__`rm <tag> [value1…]`__ : supprime les valeurs spécifiées. Si aucune valeur n'est spécifiée, toutes les valeurs associées à ce tag sont supprimées.

__`check`__ : vérifie que vous avez correctement taggé vos fichiers.

__`auto tracknumber`__ : renseigne automatiquement le tag `tracknumber`.

__`auto rename`__ : renomme les fichiers (ainsi que le dossier de l'album lorsque le mode album est activé) en se basant sur le contenu des tags. Pour cela, il est nécessaire que les fichiers soient correctement taggés (la commande `check` sera automatiquement exécutée, et le renommage ne se fera que si tous les fichiers sont correctement taggés). Selon si vous travaillez sur un album (artiste unique, date unique), un best-of (artiste unique, dates différentes), une compilation (artistes multiples) ou simplement un ensemble de fichiers ogg, les fichiers ne sont pas renommés de la même façon.

* Simple fichier
  Dossier : N/A
  Fichier ogg : ARTIST - DATE - TITLE.ogg
* Album
  Dossier : ARTIST - DATE - ALBUM
  Fichier ogg : ARTIST - DATE - ALBUM - [DISCNUMBER.]TRACKNUMBER - TITLE.ogg
* Best-of
  Dossier : ARTIST - ALBUMDATE - ALBUM
  Fichier ogg : ARTIST - ALBUMDATE - ALBUM - [DISCNUMBER.]TRACKNUMBER - TITLE - DATE.ogg
* Compilation
  Dossier : ALBUM - ALBUMDATE
  Fichier ogg : ALBUM - ALBUMDATE - [DISCNUMBER.]TRACKNUMBER - ARTIST - DATE - TITLE.ogg

Les tags `DISCNUMBER` et `TRACKNUMBER` sont automatiquement alignés avec des zéros afin de permettre un tri lexicographique des fichiers.

Ces caractères ne sont pas autorisés dans un nom de fichier : `\/:*?"<>|`. Ils sont ignorés.

En mode album, les fichiers ogg sont déplacés à la racine de du dossier.

__`write`__ : sauvegarde les modifications.

__`quit`__ ou __`exit`__ : quitte OggAlbumTagger. Attention, toute modification non sauvegardée sera perdue.

## Comment tagger efficacement votre musique ?

Ces bonnes pratiques s'appliquent aux tags de type "Vorbis Comment". Elles ont été compilées par moi-même, et n'ont rien d'officiel. L'un des objectifs d'OggAlbumTagger est de vous obliger à les suivre.

Renseignez toujours les tags ARTIST, TITLE et DATE (OggAlbumTagger requiert une année).

Pour un album, un best-of ou une compilation, renseignez les tags ALBUM et TRACKNUMBER. S'il y a plusieurs disques, renseignez le tag DISCNUMBER. N'alignez pas les tags TRACKNUMBER et DISCNUMBER avec des zéros (si votre lecteur multimédia ne sait pas que 2 vient avant 10, changez-en). Si les morceaux d'un best-of ou une compilation ont été composées à des DATEs différentes, renseignez le tag ALBUMDATE.

Pour une compilation, attribuez la valeur "Various artists" au tag ALBUMARTIST. Cela vous permettra de rechercher facilement l'ensemble de vos compilations.

Les tags ALBUM, ARTIST, ALBUMARTIST et TITLE sont conçus pour répondre à un besoin d'affichage simple. S'ils sont utilisés, ils ne doivent contenir qu'une unique valeur.

Vous pouvez spécifier des valeurs alternatives en utilisant les tags ALBUMSORT, ARTISTSORT, ALBUMARTISTSORT et TITLESORT. Le tag ARTISTSORT est particulièrement utile pour lister tous les membres d'un groupe (afin qu'une recherche sur "John Lennon" vous renvoie à la fois ses morceaux des années Beatles et ses morceaux "expérimentaux" composés avec Yoko Ono), ou encore pour faire en sorte que les Beatles soient listés à la lettre "B" et Bob Dylan en tant que "Dylan, Bob". Si votre lecteur multimédia ne supporte pas ces tags, changez-en.

Essayez d'attribuer un GENRE (ou plusieurs) à vos morceaux. Mais à moins que vous soyez un audiophile averti, ne soyez pas trop précis ou trop exhaustif, car cela rendra les recherches par genre complexes et inutiles. Utilisez uniquement les genres que vous êtes capable de reconnaitre, spécifiez les genres de base (cette [liste](http://id3.org/id3v2.3.0#Appendix_A_-_Genre_List_from_ID3v1) est une bonne base) ou cassez les genres composés (ex. "Pop-Rock").

Si vous avez besoin d'autre tags, vous pouvez aller voir [içi](http://www.xiph.org/vorbis/doc/v-comment.html) ou [là](http://www.legroom.net/2009/05/09/ogg-vorbis-and-flac-comment-field-recommendations).

## Comment ça s'installe ?

Vous aurez tout d'abord besoin d'installer :

* L'outil `exiftool`.
* La bibliothèque `libtag` ainsi que son package de développement.
* Le package de développement Ruby.

Sur un système Debian/Ubuntu récent, cela revient à :

```
$ apt-get install libimage-exiftool-perl libtag1-dev ruby-dev
```

Ensuite, installez le gem `ogg_album_tagger` :

```
$ gem install ogg_album_tagger
```

## Comment contribuer ?

Premièrement, vous devez installer les dépendances listées précédemment.

Ensuite, installez les gems `rake` et `bundle` : `gem install rake bundle`.

Enfin, exécutez `bundle install` afin d'installer les dépendances Ruby.

Vous pourrez alors :

* Exécuter OggAlbumTagger : `bundle exec ogg-album-tagger …`.
* Executer les tests : `rake test` ou `m test/test_something.rb[:line]` pour executer un sous-ensemble des tests.
* L'installer : `rake install`.
* Générer le gem : `gem build ogg_album_tagger.gemspec`.

## TODO

* Intégrer la documentation, à l'aide d'une option `--help`, d'une commande `help`, de manpages…
* S'assurer de l'utilisation de l'UTF-8.
* Rendre le code modulaire, afin que chaque commande soit décrite par une unique classe qui s'intègre dans les méthodes d'auto-complétion, d'auto-suggestion…
* Permettre l'utilisation de commentaires multi-lignes.

Les fonctionnalités suivantes n'ont pas forcément besoin d'être implémentées. Personnellement, je n'en ai pas besoin. Si vous avez du temps à y consacrer, vos contributions sont les bienvenues.

* Support d'autre formats audio : OggAlbumTagger utilise le [gem TagLib](http://robinst.github.io/taglib-ruby/), qui supporte les principaux formats audio. En théorie, il est possible de les supporter. En pratique, je n'ai aucune envie de me battre avec ces affreux tags ID3, leurs versions et leurs encodages. Si vous avez besoin de cette fonctionnalité, réfléchissez à convertir votre médiathèque en Ogg, ce sera probablement plus simple (je l'ai fait, je ne le regrette pas).
* Remplissage automatique des tags depuis les noms des fichiers ou bien de bases de données CDDB/FreeDB/… En attendant, vous pouvez par exemple utiliser [lltags](http://home.gna.org/lltag/).
* Export des pochettes d'album.
* Toute fonctionnalité dont vous auriez besoin…


## License

OggAlbumTagger est sous licence MIT. Référez-vous au fichier LICENSE.txt pour plus d'informations.
