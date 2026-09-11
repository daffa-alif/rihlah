import { NestFactory } from '@nestjs/core';
import { MatchingWorkerModule } from './matching-worker.module';

/**
 * Matching Worker — a lightweight Cloud Run service that processes dispatch
 * cascades: offer expiry → next driver → radius expansion → exhaustion.
 *
 * Runs independently from the API so cascade timeouts are never blocked
 * by request-handling load.
 */
async function bootstrap() {
  const app = await NestFactory.create(MatchingWorkerModule);
  const port = process.env.PORT || 8081;
  await app.listen(port);
  console.log(`RIHLAH Matching Worker running on port ${port}`);
}

bootstrap();
