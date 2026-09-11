import { Module } from '@nestjs/common';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { APP_GUARD, APP_INTERCEPTOR, APP_FILTER } from '@nestjs/core';
import { DatabaseModule } from '@rihlah/database';
import { FirebaseModule } from '@rihlah/firebase';
import { AuditLogInterceptor, HttpExceptionFilter } from '@rihlah/common';
import { UsersModule } from './users/users.module';
import { TripsModule } from './trips/trips.module';
import { PaymentsModule } from './payments/payments.module';
import { PayoutsModule } from './payouts/payouts.module';
import { SosModule } from './sos/sos.module';
import { AdminModule } from './admin/admin.module';

@Module({
  imports: [
    // Rate limiting: 60 requests/min per user by default
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 60 }]),
    DatabaseModule,
    FirebaseModule,
    UsersModule,
    TripsModule,
    PaymentsModule,
    PayoutsModule,
    SosModule,
    AdminModule,
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: AuditLogInterceptor,
    },
    {
      provide: APP_FILTER,
      useClass: HttpExceptionFilter,
    },
  ],
})
export class AppModule {}
