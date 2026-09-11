import { Module } from '@nestjs/common';
import { DatabaseModule } from '@rihlah/database';
import { MatchingModule } from '@rihlah/matching';

@Module({
  imports: [DatabaseModule, MatchingModule],
})
export class MatchingWorkerModule {}
