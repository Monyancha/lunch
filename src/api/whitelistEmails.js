import { Router } from 'express';
import { WhitelistEmail } from '../models';
import errorCatcher from './helpers/errorCatcher';
import loggedIn from './helpers/loggedIn';
import { whitelistEmailPosted, whitelistEmailDeleted } from '../actions/whitelistEmails';

const router = new Router();

router
  .post(
    '/',
    loggedIn,
    async (req, res) => {
      const { email } = req.body;

      try {
        const obj = await WhitelistEmail.create({ email });

        const json = obj.toJSON();
        req.wss.broadcast(whitelistEmailPosted(json, req.user.id));
        res.status(201).send({ error: false, data: json });
      } catch (err) {
        const error = { message: 'Could not add email to whitelist. Is it already added?' };
        errorCatcher(res, error);
      }
    }
  )
  .delete(
    '/:id',
    loggedIn,
    async (req, res) => {
      const id = parseInt(req.params.id, 10);

      try {
        await WhitelistEmail.destroy({ where: { id } });

        req.wss.broadcast(whitelistEmailDeleted(id, req.user.id));
        res.status(204).send({ error: false });
      } catch (err) {
        errorCatcher(res, err);
      }
    }
  );

export default router;
