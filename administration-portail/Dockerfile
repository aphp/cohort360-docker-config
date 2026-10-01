FROM node:22

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

RUN mkdir -p src/data

CMD ["npm", "start"]