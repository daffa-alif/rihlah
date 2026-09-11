import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { PrismaService } from '@rihlah/database';

/**
 * Logs all mutating requests (POST, PATCH, PUT, DELETE) to the audit_logs table.
 * Read-only requests (GET) are not logged to keep the table manageable.
 */
@Injectable()
export class AuditLogInterceptor implements NestInterceptor {
  constructor(private readonly prisma: PrismaService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest();
    const method = request.method;

    // Only log mutating requests
    if (method === 'GET') return next.handle();

    const actorId = request.user?.uid || 'anonymous';
    const resource = this.extractResource(request.path);
    const resourceId = request.params?.id || null;
    const ipAddress = request.ip || request.connection?.remoteAddress;

    // Capture the response to get the new value
    return next.handle().pipe(
      tap((responseBody) => {
        this.prisma.auditLog
          .create({
            data: {
              actorId,
              action: method.toLowerCase(),
              resource,
              resourceId,
              newValue: responseBody ? JSON.parse(JSON.stringify(responseBody)) : undefined,
              ipAddress,
            },
          })
          .catch((err) => {
            // Non-blocking — audit failure should not break the request
            console.error('Audit log write failed:', err);
          });
      }),
    );
  }

  private extractResource(path: string): string {
    // /api/v1/trips/abc123 → trips
    const parts = path.replace('/api/v1/', '').split('/');
    return parts[0] || 'unknown';
  }
}
