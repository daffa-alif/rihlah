import { Module } from '@nestjs/common';
import { ScorerService } from './scorer.service';
import { CascadeService } from './cascade.service';

@Module({
  providers: [ScorerService, CascadeService],
  exports: [ScorerService, CascadeService],
})
export class MatchingModule {}
