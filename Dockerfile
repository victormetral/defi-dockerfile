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
