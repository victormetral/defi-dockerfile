# Rapport — Défi Dockerfile

**Auteur :** Victor Metral · Ada Tech School — Spé DevOps / Opérations et Sécurité, Bloc 2
**Formateur :** Cyril · **Énoncé :** [cbldev/defi-dockerfile](https://github.com/cbldev/defi-dockerfile)

**Objectif :** afficher « Bonjour <prénom> » sur `http://localhost:3000`, avec le style fourni, le tout dans un conteneur Docker.

**Résultat :** ✅ `Bonjour Victor` servi par le conteneur, prénom injecté au lancement, image sans secret, application lancée sans les droits root.

---

## 1. Enquête avant d'écrire le Dockerfile

| Question | Où j'ai regardé | Réponse |
|---|---|---|
| Quelle version de Node ? | `package.json` → `engines` | `>=24` → image `node:24-slim` |
| Quels fichiers pour lancer ? | `server.js` → `readFileSync` | `server.js`, `package.json` (`"type": "module"`), `public/index.html`, `public/styles.css` |
| Faut-il `npm install` ? | `package.json` → `devDependencies` | **Non** : Tailwind ne sert qu'à compiler le CSS, déjà fourni dans `public/styles.css` |
| Port et commande ? | fin de `server.js`, `scripts.start` | Port `3000`, écoute sur `0.0.0.0`, commande `node server.js` |

## 2. Le Dockerfile

```dockerfile
# Image de base : Node 24 sur Debian allégée (slim)
FROM node:24-slim
# Dossier de travail dans le conteneur
WORKDIR /app
# Fichiers nécessaires au lancement (pas de .env : c'est un secret, passé au lancement)
COPY package.json server.js ./
COPY public ./public
# Port sur lequel l'application écoute (documentation)
EXPOSE 3000
# Sécurité : lancer l'appli avec l'utilisateur non privilégié « node », pas root
USER node
# Commande de démarrage (forme « exec » : un mot par case)
CMD ["node", "server.js"]
```

### Choix et alternatives

| Choix | Alternatives écartées | Raison |
|---|---|---|
| `node:24-slim` | `node:24` (complète, plus lourde), `node:24-alpine` (musl) | Légère, Debian, aucune dépendance native à compiler |
| `COPY` explicite | `COPY . .` | On sait exactement ce qui entre dans l'image |
| Aucun `npm install` | `npm ci --omit=dev` | Aucune dépendance d'exécution : image plus légère, surface d'attaque réduite |
| `USER node` | root par défaut | Bonnes pratiques de l'image officielle Node |
| `CMD ["node", "server.js"]` | `CMD node server.js` (shell), `CMD ["npm", "start"]` | Node reçoit directement les signaux d'arrêt |

Source : [Docker Hub — image `node`](https://hub.docker.com/_/node) · [Bonnes pratiques docker-node](https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md)

## 3. Le `.dockerignore`

```
# Secrets : ne jamais les envoyer au moteur Docker
.env
.env.*
# Sauf le modèle, qui ne contient aucun secret
!.env.example
# Inutiles à l'exécution
.git
node_modules
test
```

Une ceinture de sécurité : même si un jour `COPY . .` remplace la liste explicite, le `.env` ne peut pas entrer dans l'image.

## 4. Construction et lancement

```bash
docker build -t defi-dockerfile:1.0 .
docker run -d -p 3000:3000 --env-file .env --name bonjour defi-dockerfile:1.0
```

- Contexte envoyé : **10,95 ko** (grâce au `.dockerignore`).
- 4 instructions créent des couches (`FROM`, `WORKDIR`, `COPY` ×2) ; `EXPOSE`, `USER`, `CMD` sont des métadonnées.
- Taille : 80,9 Mo compressée, 349 Mo sur disque — presque entièrement l'image de base.

## 5. Vérifications

| Test | Commande | Résultat |
|---|---|---|
| Le conteneur tourne | `docker ps --filter name=bonjour` | `Up`, `0.0.0.0:3000->3000/tcp` |
| Le serveur a démarré | `docker logs bonjour` | `http://0.0.0.0:3000` |
| La page affiche le prénom | `curl -s http://localhost:3000 \| grep Bonjour` | `Bonjour Victor` |
| L'appli ne tourne pas en root | `docker exec bonjour whoami` | `node` |
| Aucun secret dans l'image | `docker exec bonjour ls -la /app` | `package.json`, `public/`, `server.js` — **pas de `.env`** |

Bonus : les fichiers de `/app` appartiennent à `root` en lecture seule pour les autres (`-rw-r--r--`). L'utilisateur `node` peut les **lire** mais pas les **modifier** : le code de l'application est protégé même si le processus est compromis.

## 6. Fausses notes rencontrées

| Erreur | Cause | Correction |
|---|---|---|
| `COPY server.js` | Destination manquante | `COPY package.json server.js ./` |
| `EXPOSE port:3000` | Syntaxe invalide | `EXPOSE 3000` |
| `CMD ["`node server.js`"]` | Toute la commande dans une seule case, avec des backticks | `CMD ["node", "server.js"]` : un mot par case |
| Confusion `USER` / fichier | `USER` est une variable, pas un fichier à copier | Elle arrive au lancement avec `--env-file` |

## 7. Ce que je retiens

1. **Enquêter avant d'écrire** : un Dockerfile est une recette ; il faut d'abord connaître les ingrédients.
2. **`EXPOSE` documente, `-p` publie** : seul `-p` ouvre réellement le port vers l'hôte.
3. **Les secrets arrivent au lancement** (`--env-file`), jamais dans l'image : une couche garde tout, même un fichier supprimé ensuite.
4. **Moins c'est mieux** : pas de dépendance inutile, pas de root, pas de fichier superflu.
5. **Point d'attention** : `-p 3000:3000` publie sur toutes les interfaces de la machine. Pour un usage local uniquement, `-p 127.0.0.1:3000:3000` est plus sûr.
