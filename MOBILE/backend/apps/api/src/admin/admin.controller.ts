import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { AdminService } from './admin.service';
import { FirebaseAuthGuard, RolesGuard, Roles } from '@rihlah/firebase';

@Controller('admin')
@UseGuards(FirebaseAuthGuard, RolesGuard)
@Roles('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  /** Dashboard KPIs: online drivers, trips today, GMV, avg rating. */
  @Get('dashboard')
  async dashboard() {
    return this.adminService.getDashboard();
  }

  /** Weekly trip/GMV chart data (last 7 days). */
  @Get('dashboard/weekly')
  async weekly() {
    return this.adminService.getWeeklySummary();
  }

  /** Reports: GMV, platform revenue, avg fare, top drivers. */
  @Get('reports')
  async reports(@Query('period') period: number = 30) {
    return this.adminService.getReports(period);
  }
}
